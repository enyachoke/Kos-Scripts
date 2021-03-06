local mission is import("lib/mission.ks").
local ship_utils is import("lib/ship_utils.ks").
local p is import("lib/params.ks").
local lazcalc is import("lib/lazcalc.ks").
local node_exec is import("lib/node_exec.ks").
local node_set_inc_lan is import("lib/node_set_inc_lan.ks").
local hohmann is import("lib/hohmann_transfer.ks").
local hc is import("lib/hillclimb.ks").
local orbitfit is import("lib/fitness_orbit.ks").
local hohmann_return is import("lib/hohmann_return.ks").
local transfit is import("lib/fitness_transfer.ks").
local science is import("lib/science.ks").
local cn is import("lib/circle_nav.ks").
local land is import("lib/land.ks").
local landfit is import("lib/fitness_land.ks").

print "Mission Params".
print p.
list files.
local mission_base is mission(mission_definition@).
function mission_definition {
  parameter seq, seqn, ev, next.
  SET pT TO AVAILABLETHRUST.
  ev:add("Power", ship_utils["power"]).
  SET thrott to 0.

function pre_launch {
  ev:remove("Power"). ship_utils["disable"]().
  set ship:control:pilotmainthrottle to 0.
  next().
}
function launch {
  local dir to lazcalc["LAZ"](p["L"]["Alt"], p["L"]["Inc"]).
  lock steering to heading(dir, 89).
  if notfalse(p["L"]["LAN"]) {
    print "waiting for Launch window.".
    local lan_t to lazcalc["window"](p["T"]["Target"]).
    warpto(lan_t).
    wait until time:seconds >= lan_t.
  }
  SET TPID TO PIDLOOP(0.01, 0.006, 0.006, 0, 1).
  SET TPID:SETPOINT TO p["L"]["Alt"].
  if ship:body:atm:exists and notfalse(p["L"]["MAXQ"]) {
    print "MaxQ: " + p["L"]["MAXQ"].
    SET QPID TO PIDLOOP(0.1, 0.01, 0.01, 0, 1).
    SET QPID:SETPOINT TO p["L"]["MAXQ"].
    lock thrott to min(
      TPID:UPDATE(TIME:SECONDS, APOAPSIS),
      QPID:UPDATE(TIME:SECONDS, SHIP:Q * constant:ATMtokPa)
    ).
  } else { lock thrott to TPID:UPDATE(TIME:SECONDS, APOAPSIS). }
  lock throttle to thrott.
  stage.
  wait until alt:radar > p["L"]["GTAlt"].
  lock pct_alt to ((alt:radar - p["L"]["GTAlt"]) / p["L"]["Alt"]).
  lock target_pitch to 90 - (90* pct_alt^p["L"]["PitchExp"]).
  lock steering to heading(dir, target_pitch).
  if not ev:haskey("AutoStage") and p["L"]["AStage"] ev:add("AutoStage", ship_utils["auto_stage"]).
  next().
}
function coast_to_atm {
  if alt:radar > body:atm:height {
    set warp to 0. lock throttle to 0.
    if ev:haskey("AutoStage") ev:remove("AutoStage").
    wait 2. stage. wait 1. panels on.
    if not ev:haskey("Power") and p["O"]["Power"]
      ev:add("Power", ship_utils["power"]).
    next().
  }
}
function circularize_ap {
  local sma to ship:obt:SEMIMAJORAXIS. local ecc to ship:obt:ECCENTRICITY.
  if hasnode node_exec["exec"](true).
  else if (ecc < 0.0015) or (600000 > sma and ecc < 0.005) next().
  else node_exec["circularize"]().
}
function set_launch_inc_lan {
  if round(ship:obt:inclination,1) = p["L"]["Inc"] {
    next().
  } else {
    if notfalse(p["L"]["LAN"]) node_set_inc_lan["create_node"](p["L"]["Inc"],p["L"]["LAN"]).
    else node_set_inc_lan["create_node"](p["L"]["Inc"]).
    node_exec["exec"](true).
  }
}
function hohmann_transfer_target {
  local r1 to SHIP:OBT:SEMIMAJORAXIS.
  local r2 to p["O"]["Alt"] + SHIP:OBT:BODY:RADIUS.
  local d_time to eta:periapsis.
  if notfalse(p["T"]["Target"]) {
    set r2 TO p["T"]["Target"]:obt:semimajoraxis.
    print "Hohmann Transfer to Vessel: " + p["T"]["Target"] + " Offset: " + p["T"]["Offset"].
    set d_time to hohmann["time"](r1,r2, p["T"]["Target"],p["T"]["Offset"]).
  }
  lock steering to lookdirup(v(0,1,0), sun:position).
  hohmann["transfer"](r1,r2,d_time).
  local nn to nextnode.
  local data to list(time:seconds + nn:eta, nn:radialout, nn:normal, nn:prograde).
  print p["T"]["Target"]:TYPENAME.
  if p["T"]["Target"]:istype("body") {
    for step in list(10,1,0.1) {set data to hc["seek"](data, transfit["trans_fit"](p["T"]["Target"], p["T"]["Inc"], p["T"]["Alt"]), step).}
  } else if p["T"]["Target"]:istype("vessel") and p["T"]["Offset"] = 0 {
    for step in list(10,1,0.1) {set data to hc["seek"](data, transfit["rndvz_fit"](p["T"]["Target"]), step).}
  } else {
    local t to time:seconds + nn:eta. local data to list(nn:prograde).
    for step in list(5,1,0.1) {set data to hc["seek"](data, orbitfit["transfer_fit"](t, p["O"]["Alt"]), step).}
  }
  node_exec["exec"](true).
  next().
}
function hohmann_correction {
  set ct to time:seconds + (eta:transition * 0.7).
  local data is list(0,0,0).
  print "Correction Fitness".
  for step in list(10,1,0.1) {set data to hc["seek"](data, transfit["cor_fit"](ct, p["T"]["Target"], p["T"]["Inc"], p["T"]["Alt"]), step).}
  local nn to nextnode.
  if nn:deltav:mag < 0.3 remove nn.
  next().
}
function exec_node {
  if hasnode
    node_exec["exec"]().
  next().
}
function wait_for_soi_change_tbody {
  wait 5.
  lock steering to lookdirup(v(0,1,0), sun:position).
  if ship:body = p["T"]["Target"] {
    wait 30.
    next().
}}
function circularize_pe {
  local sma to ship:obt:SEMIMAJORAXIS.
  local ecc to ship:obt:ECCENTRICITY.
  if hasnode node_exec["exec"](true).
  else if (ecc < 0.0015) or (600000 > sma and ecc < 0.005) next().
  else node_exec["circularize"](true).
}
function set_orbit_inc_lan {
  if round(ship:obt:inclination,1) = p["O"]["Inc"] {
    next().
  } else {
    if notfalse(p["O"]["LAN"]) node_set_inc_lan["create_node"](p["O"]["Inc"],p["O"]["LAN"]).
    else node_set_inc_lan["create_node"](p["O"]["Inc"]).
    node_exec["exec"](true).
  }
}
function fly_over_target {
  land["FlyOverTarget"]().
  next().
}
function deorbit_node {
  land["DeorbitNode"]().
  next().
}
function cancel_surface_speed {
  local ttb to time:seconds + eta:periapsis.
  local dv to VELOCITYAT(ship, ttb):surface:mag.
  local n to node(ttb,0,0,-dv).
  add n.
  node_exec["exec"](true,1).
  next().
}
function hoverslam {
  gear on.
  lock steering to srfretrograde.
  set throt to 0.
  lock truealt to (altitude - geoposition:terrainheight).
  lock throttle to throt.
  until ((altitude - geoposition:terrainheight) < p["LND"]["RadarOffset"]) or (list("Landed","Splashed"):contains(status)) {
    set throt to min(1,max(0,(((p["LND"]["HSMOD"]/(1+constant:e^(5-1.5*truealt)))+(truealt/min(-1,(verticalspeed))))+(abs(verticalspeed)/(availablethrust/mass))))).
    wait 0.
  }
  unlock throttle.
  lock steering to up.
  next().
}
function sleep {
  print "Waiting for 15 seconds".
  wait 15.
  print "Finished Waiting".
  next().
}
function collect_science {
  print "Gathering Science".
  science["collect"]().
  next().
}
function transfer_science {
  print "Transfering Science".
  science["transfer"]().
  next().
}
function pre_launch_moon {
  ev:remove("Power"). ship_utils["disable"]().
  set ship:control:pilotmainthrottle to 0.
  SET TPID TO PIDLOOP(0.01, 0.006, 0.006, 0, 1).
  SET TPID:SETPOINT TO 15000.
  next().
}
function launch_moon {
  local dir to lazcalc["LAZ"](p["L"]["Alt"], p["L"]["Inc"]).
  lock steering to heading(dir, 88).
  stage.
  lock thrott to TPID:UPDATE(TIME:SECONDS, APOAPSIS).
  lock throttle to thrott.
  wait until ship:velocity:surface:mag > 5.
  lock steering to heading(dir, 25).
  if not ev:haskey("AutoStage") and p["L"]["AStage"] ev:add("AutoStage", ship_utils["auto_stage"]).
  next().
}
function coast_to_alt {
  if apoapsis > 15000 {
    set warp to 0. lock throttle to 0.
    if ev:haskey("AutoStage") ev:remove("AutoStage").
    panels on.
    if not ev:haskey("Power") ev:add("Power", ship_utils["power"]).
    next().
  }
}
function hohmann_transfer_return {
  hohmann_return["return"]().
  local nn to nextnode.
  local data to list(time:seconds + nn:eta, nn:radialout, nn:normal, nn:prograde).
  hc["seek"](data, transfit["trans_fit"](Kerbin, 0, 35000), 10).
  hc["seek"](data, transfit["trans_fit"](Kerbin, 0, 35000), 1).
  node_exec["exec"](true).
  next().
}
function return_correction {
  set ct to time:seconds + (eta:transition * 0.7).
  local data is list(0,0,0).
  for step in list(10,1,0.1) {set data to hc["seek"](data, transfit["cor_per_fit"](ct, p["T"]["Target"], p["T"]["Alt"]), step).}
  local nn to nextnode.
  if nn:deltav:mag < 0.1 remove nn.
  else node_exec["exec"](true).
  next().
}
function wait_for_soi_change_kerbin {
  wait 5.
  lock steering to lookdirup(v(0,1,0), sun:position).
  if ship:body = Kerbin {
    wait 30.
    next().
}}
function atmo_reentry {
  lock steering to lookdirup(v(0,1,0), sun:position).
  if Altitude < SHIP:BODY:ATM:HEIGHT + 10000 {
    lock steering to srfretrograde.
    until stage:number <= 1 {
      if STAGE:READY {STAGE.}
      else {wait 1.}
    }
    RADIATORS ON.
    ev:remove("Power"). ship_utils["disable"](). wait 5.
  } else if not ev:haskey("Power") {
    ev:add("Power", ship_utils["power"]). wait 5.
  }
  if (NOT CHUTESSAFE) { unlock steering. CHUTESSAFE ON. next().}
}
function finish {
  ship_utils["enable"]().
  deletepath("startup.ks").
  if notfalse(p["NextShip"]) {
    local template to KUniverse:GETCRAFT(p["NextShip"], "VAB"). KUniverse:LAUNCHCRAFT(template).
  } else if notfalse(p["SwitchToShp"]) { set KUniverse:ACTIVEVESSEL to p["SwitchToShp"].}
  reboot.
}
  seq:add(pre_launch@). seqn:add("pre_launch").
  seq:add(launch@). seqn:add("launch").
  seq:add(coast_to_atm@). seqn:add("coast_to_atm").
  seq:add(circularize_ap@). seqn:add("circularize_ap").
  seq:add(set_launch_inc_lan@). seqn:add("set_launch_inc_lan").
  seq:add(hohmann_transfer_target@). seqn:add("hohmann_transfer_target").
  seq:add(hohmann_correction@). seqn:add("hohmann_correction").
  seq:add(exec_node@). seqn:add("exec_node").
  seq:add(wait_for_soi_change_tbody@). seqn:add("wait_for_soi_change_tbody").
  seq:add(circularize_pe@). seqn:add("circularize_pe").
  seq:add(set_orbit_inc_lan@). seqn:add("set_orbit_inc_lan").
  seq:add(fly_over_target@). seqn:add("fly_over_target").
  seq:add(deorbit_node@). seqn:add("deorbit_node").
  seq:add(cancel_surface_speed@). seqn:add("cancel_surface_speed").
  seq:add(hoverslam@). seqn:add("hoverslam").
  seq:add(sleep@). seqn:add("sleep").
  seq:add(collect_science@). seqn:add("collect_science").
  seq:add(transfer_science@). seqn:add("transfer_science").
  seq:add(pre_launch_moon@). seqn:add("pre_launch_moon").
  seq:add(launch_moon@). seqn:add("launch_moon").
  seq:add(coast_to_alt@). seqn:add("coast_to_alt").
  seq:add(circularize_ap@). seqn:add("circularize_ap").
  seq:add(set_orbit_inc_lan@). seqn:add("set_orbit_inc_lan").
  seq:add(hohmann_transfer_return@). seqn:add("hohmann_transfer_return").
  seq:add(return_correction@). seqn:add("return_correction").
  seq:add(wait_for_soi_change_kerbin@). seqn:add("wait_for_soi_change_kerbin").
  seq:add(atmo_reentry@). seqn:add("atmo_reentry").
  seq:add(finish@). seqn:add("finish").
}
export(mission_base).
