{
  local node_exec to lex(
    "exec", exec@, "circularize", circularize@,
    "clean", clean@, "make", make_node@
   ).
  function exec {
    parameter autowarp is 0, tmod is 0.6, n is nextnode, v is n:burnvector,
              starttime is (time:seconds + n:eta - mnv_time(v:mag)*tmod).
    if (starttime-300) >= time:seconds {
      lock steering to lookdirup(v(0,1,0), sun:position).
      wait until VANG(SHIP:FACING:VECTOR, lookdirup(v(0,1,0), sun:position):vector) < 0.05.
      if autowarp { warpto(starttime - 300). }
      wait until time:seconds >= (starttime - 300).
    }
    lock steering to n:burnvector. wait until VANG(SHIP:FACING:VECTOR, n:BURNVECTOR) < 1.
    if autowarp warpto(starttime - 30).
    wait until time:seconds >= starttime. lock throttle to min(mnv_time(n:burnvector:mag), 1).
    until vdot(n:burnvector, v) < 0.01 { if ship:maxthrust < 0.1 stage. wait 0.1. if ship:maxthrust < 0.1 { break. } }
    lock throttle to 0. unlock steering. remove nextnode. wait 0.
  }
  function circularize {
    parameter peri is false.
    local co TO ship:orbit. local cobr to co:body:radius.
    if peri { set cot to co:periapsis. set ttb to ETA:PERIAPSIS.}
    else { set cot to co:apoapsis. set ttb to ETA:APOAPSIS.}
    local cotcobr to (cot + cobr).
    local vat TO sqrt(co:body:mu * (2 / cotcobr - 1 / (co:semimajoraxis))).
    local cv TO sqrt(co:body:mu * (1 / cotcobr)).
    ADD NODE(TIME:SECONDS + ttb, 0, 0, cv - vat).
  }
  function mnv_time {
    parameter dV.
    local g is ship:orbit:body:mu/ship:obt:body:radius^2.
    local m is ship:mass * 1000. local e is constant():e.
    local engine_count is 0. local thrust is 0. local isp is 0.
    list engines in all_engines.
    for en in all_engines if en:ignition and not en:flameout {
      set thrust to thrust + en:availablethrust. set isp to isp + en:isp. set engine_count to engine_count + 1.
    }
    if engine_count > 0 {
      set isp to isp / engine_count. set thrust to thrust * 1000. return g * m * isp * (1 - e^(-dV/(g*isp))) / thrust.
    } else { return 0.}
  }
  function clean {until not hasnode {remove nextnode. wait 0.01.}}
  function make_node { parameter d. clean(). local n to node(d[0], d[1], d[2], d[3]). add n. wait 0. return n.}
  export(node_exec).
}
