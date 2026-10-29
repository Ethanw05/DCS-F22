-- GPL-3.0-or-later. One format contract for all four main displays.
local P={menu=0,tsd=1,stores=6,nav=7,eng=8,fcs=9,fuel=10,adi=11,checks=12,def=13,irst=14}
local M={pages=P,panels={'LMFD','RMFD','CMFD','PMFD'},
 order={P.tsd,P.nav,P.stores,P.def,P.adi,P.eng,P.fcs,P.fuel,P.checks,P.irst},
 suffix={[0]='MENU_PAGE',[1]='RDR_PAGE',[6]='BAY_PAGE',[7]='HSI_PAGE',[8]='ENG_PAGE',
  [9]='FCS_PAGE',[10]='FUEL_PAGE',[11]='ADI_PAGE',[12]='CHECKLIST_PAGE',[13]='RWR_PAGE',[14]='IRST_PAGE'},
 names={[0]='MENU',[1]='TSD',[6]='STORES',[7]='NAV',[8]='ENG',[9]='FCS',[10]='FUEL',
  [11]='ADI',[12]='CHECKS',[13]='DEF',[14]='IRST'},
 primary_bezel_first=11201,primary_bezel_last=11220,primary_menu=11221,primary_stores_activate=11222}
function M.flag(panel,page)
 if panel=='PMFD'and page==P.stores then return 'PMFD_STORES_PAGE'end
 return panel..'_'..assert(M.suffix[page],'unknown MFD format')
end
M.formats={};for page in pairs(M.suffix)do M.formats[page]=M.flag('PMFD',page)end
-- Historical side-page transport is retained for external consumers.
M.legacy={[0]=0,[1]=9,[6]=5,[7]=8,[8]=1,[9]=2,[10]=3,[11]=4,[12]=6,[13]=7,[14]=10}
return M
