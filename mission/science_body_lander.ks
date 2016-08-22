set download_files to list(
  "launch.ks",
  "land.ks",
  "collect_science.ks",
  "hohmann_transfer.ks",
  "hohmann_transfer_return.ks",
  "mission_runmodes.ks",
  "node_functions.ks",
  "soi_change.ks",
  "ship_utils.ks"
).
for df in download_files {
  DOWNLOAD("lib/" + df).
}
for df in download_files {
  RUNONCEPATH("lib/" + df).
}

if core:volume:exists("mission.json") {
  set mission to readjson("mission.json").
} else {
  set mission to lex("PitchExp", 0.4).
}

if mission:haskey("Body")
  set target_body to BODY(mission["Body"]).
else
  set target_body to Mun.

if mission:haskey("Altitude")
  set target_alt to mission["Altitude"].
else
  set target_alt to BODY:ATM:HEIGHT + 10000.

if mission:haskey("Lat")
  set target_lat to mission["Lat"].
else
  set target_lat to 0.

if mission:haskey("Lng")
  set target_lat to mission["Lng"].
else
  set target_lat to 0.

set hohmann_lex to lex(
  "Title",
  "Hohmann Transfer to " + mission["Body"],
  "Function", hohmann_transfer@,
  "Params", lex("Body", target_body, "Altitude", target_alt)
).
set execute_manuver to lex(
  "Title", "Execute Manuver Node (Warp)",
  "Function", execute_node@,
  "Params", lex("Warp", true)
).
set execute_manuver_nowarp to lex(
  "Title", "Execute Manuver Node",
  "Function", execute_node@
).

set main_sequence to list(
  lex(
    "Title", "Launch with Pitch: " + mission["PitchExp"],
    "Function", launch@,
    "Params", lex("PitchExp", mission["PitchExp"])
    ),
  lex(
    "Title", "Gravity Turn",
    "Function", gravity_turn@
    ),
  lex(
    "Title", "Circularize Orbit",
    "Function", circularization@,
    "Params", lex("Auto Stage", true, "Warp", true)
    ),
  lex(
    "Title", "Match " + target_body:name + " Inclination and LAN",
    "Function", set_inc_lan@,
    "Params", lex("Inc", target_body:OBT:INCLINATION ,"LAN", target_body:OBT:LAN)
    ),
  execute_manuver,
  hohmann_lex,
  execute_manuver,
  lex(
    "Title", "Verify Hohmann Transfer",
    "Function", manuver_alt_verification@,
    "Params", lex("Body", target_body, "Delay", 300, "Altitude", target_alt)
  ),
  execute_manuver_nowarp,
  lex(
    "Title", "Wait for SOI Change (" + target_body:name + ")",
    "Function", wait_for_soi_change@,
    "Params", lex("Body", target_body)
  ),
  lex(
    "Title", "Circularize Orbit",
    "Function", circularization@,
    "Params", lex("Mode", "pariapsis", "Warp", true)
    ),
  lex(
   "Title", "Land at Lat: " + target_lat + " Lng:" + target_lng,
   "Function", land_at_position@,
   "Params", lex("Lat", target_lat, "Lng", target_lng)
  ),
  lex(
    "Title", "Launch with Pitch: " + mission["PitchExp"],
    "Function", launch@,
    "Params", lex("PitchExp", mission["PitchExp"])
    ),
  lex(
    "Title", "Gravity Turn",
    "Function", gravity_turn@
    ),
  lex(
    "Title", "Circularize Orbit",
    "Function", circularization@,
    "Params", lex("Warp", true)
    ),
  lex(
    "Title", "Hohmann Transfer Return",
    "Function", hohmann_transfer_return@
  ),
  execute_manuver,
  lex(
    "Title", "Wait for SOI Change (Kerbin)",
    "Function", wait_for_soi_change@,
    "Params", lex("Body", Kerbin)
  ),
  lex(
    "Title", "Prep For Atmospheric Reentry",
    "Function", manuver_alt_verification@,
    "Params", lex("Body", Kerbin, "Delay", 300)
  ),
  execute_manuver_nowarp,
  lex(
    "Title", "Atmospheric Reentry",
    "Function", atmospheric_reentry@
  ),
  lex(
    "Title", "Finished",
    "Function", finished@
  )
).
set events to lex(
  "Collect Science", collect_science@,
  "Power Check", ensure_power@,
  "Drop Empty Tanks", drop_empty_tanks@
).
run_mission(main_sequence, events).
REBOOT.
