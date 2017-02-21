LIST FILES IN fileList.
for file in fileList {
  if NOT LIST("boot", "update.ks"):CONTAINS(file:name) {
    DELETEPATH(file).
  }
}
COPYPATH("0:/mission/launch_to_orbit.ks", "1:/startup.ks").
set params to lex(
  "LaunchMaxQ", 25,
  "LaunchInc", 90,
  "LaunchPitchExp", 0.3,
  "OrbitPower", false,
  "OrbitAlt", 750000
).
writejson(params, "params.json").
