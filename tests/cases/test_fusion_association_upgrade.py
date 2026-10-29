"""Flight-driven awareness association: formation, identity, timing and classes."""
import unittest
from host import Host


def fixture():
    h = Host()
    h.execute("""
        A=dofile(LockOn_Options.script_path..'Systems/Tactical_Association.lua').new()
        limits={radar=20,rf=12,mws=3,datalink=75,irst=2.5}
        function radar(id,n,e)
            return {source=id,time=100,epoch=1,n=n,u=0,e=e,vn=200,vu=0,ve=0,
                az=math.atan2(e,n),el=0,velocity_valid=true,
                position_sigma_m=5,velocity_sigma_mps=2}
        end
        function donor(id,reporter,n,e)
            local o=radar(id,n,e)
            o.reporter=reporter;o.link=1;o.observation_known=false;o.received=100
            return o
        end
        function rf(id,az)
            return {source=id,time=100,epoch=1,az=az,el=0,general=1,
                world={math.cos(az),0,math.sin(az)},
                bearing_origin={n=0,u=0,e=0,time=100}}
        end
        function run(now,r,d,f,m,i)
            A:associate({radar={epoch=1,contacts=r or {}},datalink={contacts=d or {}},
                rf={contacts=f or {}},mws={contacts=m or {}},irst={contacts=i or {}}},now,limits)
        end
    """)
    return h


class FusionAssociationUpgrade(unittest.TestCase):
    def test_native_unknown_clock_reports_resolve_two_close_aircraft(self):
        h = fixture()
        h.execute("""
            r1=radar(1,20000,0);r2=radar(2,20000,400)
            d1=donor(91,800,20030,5);d2=donor(92,800,19970,395)
            run(100,{r1,r2},{d1,d2})
            assert(r1.picture_source==d1.picture_source)
            assert(r2.picture_source==d2.picture_source)
            assert(r1.picture_source~=r2.picture_source)
            assert(d1.observation_known==false and d1.time==100 and d1.received==100)
        """)

    def test_ambiguous_formation_and_bearing_remain_distinct(self):
        h = fixture()
        h.execute("""
            r1=radar(1,20000,-200);r2=radar(2,20000,200)
            d=donor(91,800,20000,0);f=rf(999,0)
            run(100,{r1,r2},{d},{f})
            assert(r1.picture_source~=r2.picture_source)
            assert(d.picture_source~=r1.picture_source and d.picture_source~=r2.picture_source)
            assert(f.picture_source~=r1.picture_source and f.picture_source~=r2.picture_source)
        """)

    def test_wingman_ppli_uses_qualified_id_and_preserves_other_emitter(self):
        h = fixture()
        h.execute("""
            d=donor(16777984,16777984,20000,0);d.ppli=true;d.friendly=true
            f=rf(16777984,0);other=rf(16777728,.001)
            run(100,nil,{d},{f,other})
            assert(d.picture_source==f.picture_source)
            assert(other.picture_source~=f.picture_source)
            d.ppli=false;A:reset();run(100,nil,{d},{f,other})
            assert(d.picture_source~=f.picture_source)
        """)

    def test_multiple_reporters_share_one_aircraft_without_merging_their_other_tracks(self):
        h = fixture()
        h.execute("""
            r=radar(1,20000,0)
            d1=donor(1,800,20020,0);d2=donor(1,801,19980,0)
            other=donor(2,800,20000,400)
            run(100,{r},{d1,d2,other})
            assert(r.picture_source==d1.picture_source and r.picture_source==d2.picture_source)
            assert(other.picture_source~=r.picture_source)
        """)

    def test_maws_rf_missile_stays_separate_from_aircraft_and_irst(self):
        h = fixture()
        h.execute("""
            r=radar(1,20000,0);d=donor(3,800,20000,0)
            f=rf(99,0);f.general=3
            m={source=90,time=100,epoch=1,az=0,el=0}
            i={source=80,time=100,epoch=1,az=0,el=0}
            run(100,{r},{d},{f},{m},{i})
            assert(m.picture_source==f.picture_source)
            assert(m.picture_source~=r.picture_source and m.picture_source~=i.picture_source)
            assert(r.picture_source==i.picture_source and r.picture_source==d.picture_source)
        """)

    def test_rf_uses_original_reception_geometry_and_donor_receive_estimate(self):
        h = fixture()
        h.execute("""
            d=donor(3,800,20000,0);d.vn=0;d.ve=200
            f=rf(99,0)
            run(102,nil,{d},{f})
            assert(d.picture_source==f.picture_source)
            assert(d.received==100 and d.observation_known==false)
            A:reset();f.time=114;f.bearing_origin.time=114
            run(114,nil,{d},{f})
            assert(d.picture_source~=f.picture_source)
        """)

    def test_fused_identity_survives_sensor_handover_but_not_split_or_epoch_reset(self):
        h = fixture()
        h.execute("""
            r=radar(1,20000,0);f=rf(99,0)
            run(100,{r},nil,{f});old=r.picture_source
            run(100.1,nil,nil,{f});assert(f.picture_source==old)
            run(100.1,{r},nil,{f});assert(r.picture_source==old)
            f.az=1;f.world={math.cos(1),0,math.sin(1)}
            run(100.2,{r},nil,{f});assert(r.picture_source~=f.picture_source)
            old=f.picture_source;f.epoch=2
            run(100.3,nil,nil,{f});assert(f.picture_source~=old)
        """)

    def test_missing_geometry_or_unknown_clock_without_receipt_cannot_gain_position(self):
        h = fixture()
        h.execute("""
            r=radar(1,20000,0);d=donor(3,800,20000,0);d.received=nil
            run(100,{r},{d});assert(r.picture_source~=d.picture_source)
            d.received=100;d.vn=0/0
            run(100,{r},{d});assert(r.picture_source~=d.picture_source)
        """)

    def test_slow_unchanged_donor_does_not_duplicate_live_radar_after_prediction_expires(self):
        h = fixture()
        h.execute("""
            r=radar(1,20000,0);d=donor(3,800,20000,0)
            run(100,{r},{d});old=r.picture_source
            r.time=114;r.n=22800;d.az=.01
            run(114,{r},{d})
            assert(r.picture_source==old and d.picture_source==old)
            assert(d.time==100 and d.received==100 and d.observation_known==false)
            d.time=114;d.received=114;d.n=40000
            run(114,{r},{d})
            assert(r.picture_source~=d.picture_source)
        """)

    def test_own_radar_and_rwr_fuse_without_datalink_at_original_rf_epochs(self):
        h = fixture()
        h.execute("""
            r1=radar(1,20000,0);r2=radar(2,20000,6000)
            r1.vn=0;r2.vn=0;r1.ve=200;r2.ve=200
            f1=rf(99,0);f2=rf(100,math.atan2(6000,20000))
            run(100,{r1,r2},nil,{f1,f2})
            assert(r1.picture_source==f1.picture_source)
            assert(r2.picture_source==f2.picture_source and r2.picture_source~=r1.picture_source)
            r1.time=102;r2.time=102;r1.e=400;r2.e=6400
            r1.az=math.atan2(400,20000);r2.az=math.atan2(6400,20000)
            run(102,{r1,r2},nil,{f1,f2})
            assert(r1.picture_source==f1.picture_source and r2.picture_source==f2.picture_source)
        """)

    def test_transitive_donor_chain_cannot_override_current_position_contradiction(self):
        h = fixture()
        h.execute("""
            r=radar(1,20000,0)
            d1=donor(3,800,20400,0);d2=donor(4,801,20800,0)
            run(100,{r},{d1,d2})
            assert(r.picture_source~=d2.picture_source)
        """)


if __name__ == '__main__':
    unittest.main()
