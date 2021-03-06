LIST FILES IN fileList.
for file in fileList {
  if NOT LIST("boot", "update.ks"):CONTAINS(file:name) {
    DELETEPATH(file).
  }
}
COPYPATH("0:/mission/remote_tech_network.ks", "1:/startup.ks").
set params to lex(
  "LaunchPitchExp", 0.46,
  "OrbitAlt", 750000,
  "TransTarget", "CommSat Mk-I",
  "TransType", "Vessel",
  "OrbitOffset", -120,
  "NextShip", "CommSat Mk-II"
).
writejson(params, "params.json").
