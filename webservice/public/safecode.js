function set_connected_status(component, component_text, status) {
  if(status == true) {
    status_text = component_text + " Connected";
    class_name = "label label-success";
  } else if(status == false) {
    status_text = component_text + " Disconnected";
    class_name = "label label-important";
  } else {
    status_text = component_text + " Unknown";
    class_name = "label label-warning";
  }
  var elem = document.getElementById("status_" + component)
  elem.innerHTML = status_text;
  elem.className = class_name;
}

function set_last_comms(time) {
  var last_comm = document.getElementById("status_comms");
  var lost_comm_warn = document.getElementById("lost_connection");
  last_comm.innerHTML = "Last communication " + time + " seconds ago";
  if(time < 15) {
    last_comm.className = "label label-success";
    lost_comm_warn.style.cssText = "display: none;";
  } else if(time < 30) {
    last_comm.className = "label label-warning"
    lost_comm_warn.style.cssText = "display: none;";
  } else {
    last_comm.className = "label label-important"
    lost_comm_warn.style.cssText = "";
  }
}

function set_session_info(state, time, length) {
  if(state == 'not_in_session') {
    state_text = "Not in session";
    checkin_text = ""
    progress_pct = 0;
  } else if(state == 'pre_checkin') {
    state_text = "Client arrived, waiting for initial check-in";
    checkin_text = "Next check-in expected in " + Math.floor(time / 60) + "m " + time % 60 + "s";
    progress_pct = (length-time) / length * 100;
  } else if(state == 'in_session') {
    state_text = "In session, initial check-in OK";
    checkin_text = "Next check-in expected in " + Math.floor(time / 60) + "m " + time % 60 + "s";
    progress_pct = (length-time) / length * 100;
  } else if(state == 'not_ok') {
    state_text = "Initial check-in NOT OK";
    checkin_text = ""
    progress_pct = 0;
  } else {
    state_text = "Unknown";
    checkin_text = ""
    progress_pct = 0;
  }
  document.getElementById('session_state').innerHTML = state_text;
  document.getElementById('time_until_checkin').innerHTML = checkin_text;
  document.getElementById('session_progress').style.cssText = "width: " + progress_pct + "%;";
}

window.onload = function() {(
  function() {
    var ws       = new WebSocket('ws://' + window.location.host + window.location.pathname);
    var last_status;
    var last_comms = -1;
    ws.onopen    = function()  {
      set_connected_status('webservice', 'Web Service', true);
    };
    ws.onclose   = function()  {
      set_connected_status('webservice', 'Web Service', false);
      set_connected_status('daemon', 'Room Daemon', 'unknown');
      set_connected_status('box', 'SafeCode Box', 'unknown');
    }
    ws.onmessage = function(msg) {
      last_status = JSON.parse(msg.data);
      set_connected_status('daemon', 'Room Daemon', last_status.daemon_connection);
      set_connected_status('box', 'SafeCode Box', last_status.box_connection);
      set_session_info(last_status.session_state, last_status.time_until_checkin, last_status.session_length);
      last_comms = 0; 
    };
    setInterval(function() {
      if(!last_status) { return; }
      last_status.time_until_checkin--;
      set_session_info(last_status.session_state, last_status.time_until_checkin, last_status.session_length);
      last_comms++;
      set_last_comms(last_comms);
    }, 1000);
  })();
}
