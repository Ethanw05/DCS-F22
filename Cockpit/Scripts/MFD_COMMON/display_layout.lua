-- GPL-3.0-or-later. Physical LCD/bezel geometry, independent of the selected format.
-- Generated from Cockpit_F-22A.EDM connector parent chains. x and y_fraction
-- use each indicator's CENTER / RIGHT / DOWN basis; GetAspect supplies the
-- actual render aperture. MENU remains exactly at bottom center.
local profiles={
 LMFD={aspect=0.9916455596,half_width_m=0.0774774849,buttons={
  {-0.56578907,1.14327327},
  {-0.26466930,1.14327321},
  {0.00005261,1.14586293},
  {0.26677514,1.14327310},
  {0.55892469,1.14327305},
  {1.14890318,0.43515245},
  {1.14890346,0.13150244},
  {1.14890371,-0.13218987},
  {1.14890397,-0.40426753},
  {1.14890425,-0.69905310},
  {0.56266996,-1.14396003},
  {0.26155018,-1.14395997},
  {0.00005478,-1.14395992},
  {-0.26983002,-1.14395987},
  {-0.56204381,-1.14395981},
  {-1.14963486,-0.70270009},
  {-1.14963514,-0.39906846},
  {-1.14963539,-0.13535860},
  {-1.14963565,0.13679745},
  {-1.14963593,0.43150845},
 }},
 RMFD={aspect=0.9916452112,half_width_m=0.0774774998,buttons={
  {-0.56043877,1.14327361},
  {-0.25931943,1.14327355},
  {0.00540281,1.14586328},
  {0.27212528,1.14327345},
  {0.56427440,1.14327339},
  {1.15425238,0.43515269},
  {1.15425267,0.13150263},
  {1.15425292,-0.13218973},
  {1.15425317,-0.40426743},
  {1.15425346,-0.69905304},
  {0.56802005,-1.14396005},
  {0.26690071,-1.14395999},
  {0.00540497,-1.14395994},
  {-0.26447938,-1.14395989},
  {-0.55669312,-1.14395983},
  {-1.14428444,-0.70270004},
  {-1.14428472,-0.39906836},
  {-1.14428497,-0.13535846},
  {-1.14428523,0.13679763},
  {-1.14428551,0.43150868},
 }},
 CMFD={aspect=0.9916457902,half_width_m=0.0774774998,buttons={
  {-0.56572462,1.14099068},
  {-0.26465820,1.14099061},
  {-0.00309840,1.14099054},
  {0.26678652,1.14099047},
  {0.55900009,1.14099040},
  {1.14896744,0.43289027},
  {1.14896764,0.12929401},
  {1.14896781,-0.13440139},
  {1.14896799,-0.40659076},
  {1.14896818,-0.70130001},
  {0.55900159,-1.14623373},
  {0.26678802,-1.14623366},
  {-0.00309690,-1.14623359},
  {-0.26465669,-1.14623352},
  {-0.56572312,-1.14623345},
  {-1.14962357,-0.70129943},
  {-1.14962376,-0.40659018},
  {-1.14962394,-0.13440081},
  {-1.14962411,0.12929459},
  {-1.14962431,0.43289086},
 }},
 PMFD={aspect=0.9742971338,half_width_m=0.0932006910,buttons={
  {-0.61552104,1.16448947},
  {-0.30731514,1.16448947},
  {0.00083712,1.16448947},
  {0.30898925,1.16448947},
  {0.61724881,1.16448947},
  {1.15683748,0.55312234},
  {1.15683748,0.23680892},
  {1.15683748,-0.07955902},
  {1.15683748,-0.39582570},
  {1.15683748,-0.71218429},
  {0.61724881,-1.16648633},
  {0.30898925,-1.16648633},
  {0.00083712,-1.16648633},
  {-0.30731514,-1.16648633},
  {-0.61552104,-1.16648633},
  {-1.15645040,-0.71218366},
  {-1.15645040,-0.39582601},
  {-1.15645040,-0.07955871},
  {-1.15645040,0.23680892},
  {-1.15645040,0.55312234},
 }},
}
local M={profiles=profiles,model_sha256="da19b6bfa93081219eef0cc01610cf6fc8e506c9faf7f420b597427721e5d732"}
function M.panel(identifier)
 for _,name in ipairs({'LMFD','RMFD','CMFD','PMFD'})do
  if type(identifier)=='string'and identifier:find(name,1,true)then return name end
 end
 return 'PMFD' -- Historical stand-alone PMFD subset.
end
-- Text width in glyph heights, including a .2-height selection-box margin
-- at each end. Matches the common .60 glyph / .06 inter-character metrics.
function M.label_span(label)return #label*.66+.34 end
function M.for_display(identifier,aspect,native_scale)
 local panel=M.panel(identifier);local p=profiles[panel]
 aspect=aspect or p.aspect;native_scale=native_scale or p.half_width_m
 local ui=.95*math.min(1,aspect);local h=.0048*ui
 local font_height=h/native_scale;local edge=.975
 local vertical_edge=aspect-math.max(.025*aspect,.75*font_height)
 local result={panel=panel,aspect=aspect,font_height=h,keys={}}
 for button,point in ipairs(p.buttons)do
  local top=button<=5;local bottom=button>=11 and button<=15
  local x,y,alignment
  if top or bottom then
   x=button==13 and 0 or point[1];y=(top and 1 or -1)*vertical_edge;alignment='CenterCenter'
  else
   local right=button<=10;x=(right and 1 or -1)*edge
   y=point[2]*aspect;alignment=right and 'RightCenter'or'LeftCenter'
  end
  result.keys[button]={x=x,y=y,alignment=alignment,side=not(top or bottom),right=button<=10}
 end
 -- Six-character ACTIVE is the widest ground-radar side label. Leave only
 -- its measured text/box width and a small gap; use the rest for the image.
 local half_width=math.min(.90,edge-(M.label_span('ACTIVE')-.2)*font_height-.02)
 result.ground_plot={half_width=half_width,half_height=.82*aspect,
  x_scale=half_width/.825,y_scale=.82*aspect/.76,readout_y=.89*aspect,status_y=-.91*aspect}
 return result
end
return M
