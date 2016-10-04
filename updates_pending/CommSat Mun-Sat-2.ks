LIST FILES IN fileList.
for file in fileList {
  if NOT LIST("boot", "update.ks"):CONTAINS(file:name) {
    DELETEPATH(file).
  }
}
COPYPATH("0:/mission/rt_mun_network.ks", "1:/startup.ks").
set params to lex(
  "Vessel", "CommSat Mun-Sat-I",
  "Offset", 120 * 1
).
writejson(params, "params.json").
