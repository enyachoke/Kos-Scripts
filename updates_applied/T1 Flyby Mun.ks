LIST FILES IN fileList.
for file in fileList {
  if NOT LIST("boot", "update.ks"):CONTAINS(file:name) {
    DELETEPATH(file).
  }
}
COPYPATH("0:/mission/moon_flyby.ks", "1:/startup.ks").
set params to lex(
  "LaunchGTAlt", 1000,
  "LaunchPitchExp", 0.45,
  "TransTarget", "Mun",
  "TransType", "Body",
  "TransInc", 178
).
writejson(params, "params.json").
