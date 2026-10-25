-- Decode DCS cockpit-device bindings; internal dispatch values stay unmodified.
-- Observed physical device16: press=16.375, release=16.25.
return function(value,device)
 value=value or 0
 if value>=device+.125-1e-5 and value<=device+.375+1e-5 then
  return (value-device-.25)*8
 end
 return value
end
