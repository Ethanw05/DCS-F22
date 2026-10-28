// Independent analytic transport/covariance and ambiguity cases; no old test oracle.
#include "../../EFM/source/AesaTrackFilter.h"
#include "../../EFM/source/AesaAssociation.h"
#include <cstdlib>
#include <iostream>
#include <limits>

namespace {
using namespace AesaTrackFilter;
void require(bool condition,const char* message) {
    if(!condition){std::cerr<<"FAIL: "<<message<<'\n';std::exit(1);}
}
Sample observe(Vector position,Vector velocity,Vector origin,Vector own_velocity,double time,double heading) {
    const Vector forward{std::cos(heading),0,std::sin(heading)};
    const Vector right{-std::sin(heading),0,std::cos(heading)};
    Vector delta{},relative{};
    for(std::size_t axis=0;axis<3;++axis){delta[axis]=position[axis]-origin[axis];relative[axis]=velocity[axis]-own_velocity[axis];}
    const double range=std::hypot(delta[0],delta[1],delta[2]);
    const double along=delta[0]*forward[0]+delta[2]*forward[2];
    const double across=delta[0]*right[0]+delta[2]*right[2];
    Sample sample;
    sample.origin=origin;sample.own_velocity=own_velocity;sample.forward=forward;sample.right=right;
    sample.time=time;sample.range=range;sample.azimuth=std::atan2(across,along);
    sample.elevation=std::atan2(delta[1],std::hypot(along,across));
    sample.range_rate=(relative[0]*delta[0]+relative[1]*delta[1]+relative[2]*delta[2])/range;
    sample.range_sigma=1;sample.angle_sigma=.0001;sample.rate_sigma=.1;
    return sample;
}
void covariance(const Estimate& state) {
    Matrix lower{};
    for(std::size_t i=0;i<6;++i)for(std::size_t j=0;j<=i;++j) {
        require(std::isfinite(state.covariance[i][j]),"nonfinite covariance");
        require(std::abs(state.covariance[i][j]-state.covariance[j][i])<1e-8,
                "covariance lost symmetry");
        double residual=state.covariance[i][j];
        for(std::size_t k=0;k<j;++k)residual-=lower[i][k]*lower[j][k];
        if(i==j){require(residual>0,"independent Cholesky found nonpositive covariance");lower[i][j]=std::sqrt(residual);}
        else lower[i][j]=residual/lower[j][j];
    }
}
void constant_velocity() {
    unsigned observations=0;
    for(double heading:{0.0,179*pi/180,-179*pi/180})for(double interval:{.02,.1,.4}) {
        Filter filter;
        const Vector velocity{20,2,-12},own_velocity{3,0,5};
        for(unsigned step=0;step<80;++step) {
            const double time=step*interval;
            const Vector truth{10000+20*time,4000+2*time,1000-12*time};
            const Vector origin{3*time,100,5*time};
            const auto measurement=observe(truth,velocity,origin,own_velocity,time,heading);
            require(filter.observe(measurement),"qualified analytic CV sample rejected");
            const auto& state=filter.state();
            require(state.time==time&&state.hits==step+1,"source time/hit accounting changed");
            covariance(state);
            for(double coordinate:state.position)require(std::isfinite(coordinate),"nonfinite CV state");
            if(step==0)for(std::size_t axis=0;axis<3;++axis)
                require(std::abs(state.position[axis]-truth[axis])<1e-6,"independent spherical-to-world transport mismatch");
            if(step>=30)for(std::size_t axis=0;axis<3;++axis) {
                require(std::abs(state.position[axis]-truth[axis])<1,"CV position convergence exceeds declared software tolerance");
                require(std::abs(state.velocity[axis]-velocity[axis])<1,"CV velocity convergence exceeds declared software tolerance");
            }
            ++observations;
        }
    }
    std::cout<<"PASS analytic CV/wrap/cadence: "<<observations<<" observations and independent SPD checks\n";
}
void failure_recovery() {
    Filter filter;
    auto sample=observe({10000,0,0},{20,0,0},{},{},0,0);
    require(filter.observe(sample),"finite zero sample time rejected");
    require(filter.state().position[0]==10000,"zero-angle transport changed");
    require(!filter.observe(sample)&&filter.state().hits==1,"same-clock report repeated integration");
    const double nan=std::numeric_limits<double>::quiet_NaN();
    const double inf=std::numeric_limits<double>::infinity();
    for(unsigned field=0;field<7;++field)for(double bad:{nan,inf,-inf}) {
        auto malformed=sample;malformed.time=.1;
        if(field==0)malformed.range=bad;
        if(field==1)malformed.azimuth=bad;
        if(field==2)malformed.elevation=bad;
        if(field==3)malformed.range_rate=bad;
        if(field==4)malformed.range_sigma=bad;
        if(field==5)malformed.origin[0]=bad;
        if(field==6)malformed.forward[0]=bad;
        require(!filter.observe(malformed)&&filter.state().time==0,"malformed sample poisoned accepted state");
    }
    sample=observe({10002,0,0},{20,0,0},{},{},.1,0);
    const auto before=filter.state();
    require(std::isfinite(filter.association_score(sample))&&filter.state().time==before.time&&
        filter.state().covariance==before.covariance,"association scoring mutated the measured observation");
    require(filter.observe(sample)&&filter.state().time==.1,"fresh observation did not restore after rejection");
    auto jump=observe({40000,0,0},{20,0,0},{},{},.2,0);
    require(filter.association_score(jump)>AesaAssociation::gate,"impossible displacement passed innovation gate");
    require(!filter.observe(jump)&&filter.state().time==.1,"outlier dragged established measured state");
    filter.reset();require(!filter.state().valid&&filter.state().hits==0,"explicit generation reset retained filter");
    require(filter.observe(observe({5000,0,0},{},{},{},0,0)),"fresh generation zero-time recovery failed");
    std::cout<<"PASS finite-zero, malformed sample, non-mutating score, outlier and reset recovery\n";
}
void angular_wrap_transition() {
    Filter filter;
    for(unsigned step=0;step<100;++step) {
        const double time=step*.1;
        const double heading=((step%2)?179.0:-179.0)*pi/180;
        const auto sample=observe({10000+20*time,0,0},{20,0,0},{},{},time,heading);
        require(filter.observe(sample),"wrapped bearing transition rejected a coherent world measurement");
        require(std::abs(filter.state().position[0]-(10000+20*time))<1e-6&&
            std::abs(filter.state().position[2])<1e-6,"angular wrap changed world position");
        covariance(filter.state());
    }
    std::cout<<"PASS100 alternating -179/+179 heading transitions with unchanged world CV\n";
}
void ambiguity() {
    using namespace AesaAssociation;
    Assignment unique;
    unique.offer(0,0,1);unique.offer(0,1,20);unique.offer(1,0,20);unique.offer(1,1,1);
    require(unique.selected(0)==0&&unique.selected(1)==1,"unique reciprocal measurement assignment failed");
    Assignment crossing;
    for(std::size_t row=0;row<2;++row)for(std::size_t track=0;track<2;++track)crossing.offer(row,track,1);
    require(crossing.selected(0)==none&&crossing.selected(1)==none,"ambiguous crossing fabricated unique correspondence");
    Choice boundary;boundary.offer(1,gate);require(boundary.clear(),"exact innovation gate rejected");
    Choice beyond;beyond.offer(1,gate+1e-6);require(!beyond.clear(),"outside innovation gate accepted");
    Choice separation_limit;separation_limit.offer(1,1);separation_limit.offer(2,1+separation);
    require(separation_limit.clear(),"declared alternative-separation boundary rejected");
    Filter left,right;
    require(left.observe(observe({10000,0,-1},{},{},{},0,0))&&
        right.observe(observe({10000,0,1},{},{},{},0,0)),"crossing filters did not initialize");
    const auto merged=observe({10000,0,0},{},{},{},.1,0);
    Assignment measured;
    for(std::size_t report=0;report<2;++report) {
        measured.offer(report,0,left.association_score(merged));
        measured.offer(report,1,right.association_score(merged));
    }
    require(measured.selected(0)==none&&measured.selected(1)==none&&left.state().time==0&&right.state().time==0,
            "actual covariance ambiguity renewed observation or granted identity");
    std::cout<<"PASS mutual assignment, declared estimate boundaries and measured covariance ambiguity\n";
}
}
int main(){constant_velocity();failure_recovery();angular_wrap_transition();ambiguity();}
