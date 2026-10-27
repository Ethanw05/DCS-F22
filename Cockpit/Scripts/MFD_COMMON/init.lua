-- GPL-3.0-or-later. Shared indicator registration; no display-specific pages.
return function(folder)
 dofile(LockOn_Options.common_script_path..'devices_defs.lua')
 indicator_type=indicator_types.COMMON;purposes={render_purpose.GENERAL}
 shaderLineParamsUpdatable=true;shaderLineDefaultThickness=1.2;shaderLineDefaultFuzziness=.2
 shaderLineDrawAsWire=false;shaderLineUseSpecularPass=false;init_pageID=1
 page_subsets={[1]=LockOn_Options.script_path..folder..'/page.lua',
  [100]=LockOn_Options.script_path..folder..'/sensor_control.lua'}
 pages={{1,100}}
end
