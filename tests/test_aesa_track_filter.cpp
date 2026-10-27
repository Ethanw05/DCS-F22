// Measured-domain estimator regression. No DCS or native target-velocity input.
#include "../EFM/source/AesaTrackFilter.h"
#include <iostream>
#include <random>
#include <stdexcept>
#include <fstream>
#include <sstream>
#define CHECK(x) do { if (!(x)) throw std::runtime_error(std::to_string(__LINE__)+": "+#x); } while (false)
using namespace AesaTrackFilter;
namespace {
double length(Vector v) { return std::sqrt(dot(v,v)); }
void covariance(const Estimate& p) {
    Matrix lower{};
    // Cholesky verifies the complete matrix, including cross-axis terms.
    for (std::size_t i=0;i<6;++i) for (std::size_t j=0;j<=i;++j) {
        CHECK(std::abs(p.covariance[i][j]-p.covariance[j][i]) < 1e-6);
        double value=p.covariance[i][j];
        for (std::size_t k=0;k<j;++k) value-=lower[i][k]*lower[j][k];
        CHECK(i!=j || value>0);
        lower[i][j]=i==j ? std::sqrt(value) : value/lower[j][j];
    }
}
Sample measure(double time,Vector target,Vector velocity, double yaw=0) {
    Sample s{};s.time=time;s.origin={250*time,3000,0};s.own_velocity={250,0,0};
    s.forward={std::cos(yaw),0,std::sin(yaw)};s.right={-std::sin(yaw),0,std::cos(yaw)};
    const auto d=difference(target,s.origin);
    s.range=length(d);s.azimuth=std::atan2(dot(d,s.right),dot(d,s.forward));
    s.elevation=std::atan2(d[1],std::hypot(d[0],d[2]));
    s.range_rate=dot(difference(velocity,s.own_velocity),d)/s.range;
    return s;
}
void moving_and_maneuver() {
    Filter filter;std::mt19937 generator(42);std::normal_distribution<double> normal;
    Vector target{30000,4500,8000},velocity{180,0,110};
    double position_rms=0,velocity_rms=0,raw_velocity_rms=0,previous_time=0;
    Vector previous{};unsigned count=0,accepted=0;
    for (unsigned i=0;i<600;++i) {
        const double dt=i%2==0 ? .034 : .23, time=previous_time+dt;
        if (i>=240 && i<320) {velocity[0]+=-12*dt;velocity[2]+=18*dt;}
        for (std::size_t j=0;j<3;++j) target[j]+=velocity[j]*dt;
        auto s=measure(time,target,velocity,.4*std::sin(time*.05));
        s.range+=normal(generator)*s.range_sigma;
        s.azimuth+=normal(generator)*s.angle_sigma;s.elevation+=normal(generator)*s.angle_sigma;
        s.range_rate+=normal(generator)*s.rate_sigma;
        const auto direction=measured_direction(s);
        Vector raw=s.origin;
        for(std::size_t j=0;j<3;++j)raw[j]+=direction[j]*s.range;
        if(filter.observe(s))++accepted;
        covariance(filter.state());
        if(i>100) {
            CHECK(filter.state().velocity_valid);
            position_rms+=std::pow(length(difference(filter.state().position,target)),2);
            velocity_rms+=std::pow(length(difference(filter.state().velocity,velocity)),2);
            Vector derivative=difference(raw,previous);
            for(auto& v:derivative)v/=dt;
            raw_velocity_rms+=std::pow(length(difference(derivative,velocity)),2);++count;
        }
        previous=raw;previous_time=time;
    }
    position_rms=std::sqrt(position_rms/count);velocity_rms=std::sqrt(velocity_rms/count);
    raw_velocity_rms=std::sqrt(raw_velocity_rms/count);
    CHECK(accepted>590 && position_rms<80 && velocity_rms<50 && raw_velocity_rms>velocity_rms*5);
    std::cout<<"Irregular revisits with ownship rotation and maneuver: position RMS "<<position_rms
        <<" m, velocity RMS "<<velocity_rms<<" m/s (raw derivative "<<raw_velocity_rms<<")\n";
}
void authority_and_outliers() {
    Filter filter;auto s=measure(0,{30000,3000,0},{100,0,400});
    CHECK(filter.observe(s) && !filter.state().velocity_valid);
    CHECK(filter.state().covariance[5][5]>=249999); // Doppler never measures transverse velocity.
    CHECK(!filter.observe(s) && filter.state().hits==1);
    for(unsigned i=1;i<100;++i) {
        const double time=i*.1;
        s=measure(time,{30000+100*time,3000,400*time},{100,0,400});
        CHECK(filter.observe(s));
    }
    CHECK(filter.state().velocity_valid && std::abs(filter.state().velocity[2]-400)<5);
    const auto before=filter.state();
    for(unsigned i=0;i<3;++i) {
        auto bad=s;bad.time+=.1*(i+1);bad.range+=10000;
        CHECK(!filter.observe(bad));
        CHECK(filter.state().time==before.time && filter.state().hits==before.hits);
    }
    const double resume=s.time+1;
    s=measure(resume,{30000+100*resume,3000,400*resume},{100,0,400});
    CHECK(filter.observe(s)); // Genuine missed revisits propagate covariance, not extra hits.
    CHECK(filter.state().hits==before.hits+1);
    s.time+=7;CHECK(filter.observe(s) && !filter.state().velocity_valid && filter.state().hits==1);
    auto bad=s;bad.time+=.1;bad.range=std::numeric_limits<double>::quiet_NaN();CHECK(!filter.observe(bad));
    bad=s;bad.time+=.1;bad.forward={2,0,0};CHECK(!filter.observe(bad));
    filter.reset();CHECK(!filter.state().valid);
}
void replay(const char* path) {
    std::ifstream input(path);CHECK(input.good());std::string line;std::getline(input,line);
    Filter filter;Vector previous{},last_velocity{},recorded_velocity{};double last_time=-1,raw_steps=0,filtered_steps=0;
    unsigned accepted=0,count=0;
    while(std::getline(input,line) && count<200) {
        std::istringstream row(line);std::array<double,7> v{};std::string cell;
        for(auto& value:v){CHECK(static_cast<bool>(std::getline(row,cell,',')));value=std::stod(cell);}
        Sample s{};s.time=v[0];s.origin={v[4],v[5],v[6]};const Vector raw{v[1],v[2],v[3]};
        const auto d=difference(raw,s.origin);s.range=length(d);s.azimuth=std::atan2(d[2],d[0]);
        s.elevation=std::atan2(d[1],std::hypot(d[0],d[2]));s.rate_valid=false;
        s.range_sigma=9;s.angle_sigma=.00036;
        if(filter.observe(s))++accepted;
        covariance(filter.state());
        if(last_time>=0) {
            const double dt=s.time-last_time;auto raw_velocity=difference(raw,previous);
            for(auto& axis:raw_velocity)axis/=dt;
            if(count>20) {
                raw_steps+=length(difference(raw_velocity,last_velocity));
                filtered_steps+=length(difference(filter.state().velocity,recorded_velocity));
            }
            last_velocity=raw_velocity;
        }
        previous=raw;last_time=s.time;recorded_velocity=filter.state().velocity;++count;
    }
    CHECK(count==160 && accepted>150 && raw_steps>filtered_steps*5);
    std::cout<<"Archived position-only replay: "<<accepted<<"/"<<count<<" reports accepted, mean velocity step "
        <<filtered_steps/(count-21)<<" m/s (raw "<<raw_steps/(count-21)<<"). No recorded Doppler exists.\n";
}
}
int main(int argc,char** argv) {
    try {moving_and_maneuver();authority_and_outliers();if(argc>1)replay(argv[1]);return 0;}
    catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
