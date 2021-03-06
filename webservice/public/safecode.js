function resetForm(formName) {
  document.getElementById(formName).reset();
}

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

function pretty_duration(secs) {
  hours = Math.floor(secs / (60 * 60));
  mins = Math.floor((secs - hours*60*60) / 60);
  secs = secs % 60;
  if(hours > 0) {
    return hours + "h " + mins + "m " + secs + "s";
  } else if(mins > 0) {
    return mins + "m " + secs + "s";
  } else {
    return secs + " seconds";
  }
}

function set_session_info(state, distress, time, length) {
  if(state == 'not_in_session') {
    state_text = "Not in session";
    checkin_text = ""
    progress_pct = 0;
    bar_class = "success";
  } else if(state == 'pre_checkin') {
    state_text = "Client arrived, waiting for initial check-in";
    checkin_text = "Next check-in expected in " + pretty_duration(time);
    progress_pct = (length-time) / length * 100;
    if(time >= 0) {
      bar_class = "success";
      checkin_text = "Next check-in expected in " + pretty_duration(time);
    } else {
      bar_class = "danger active";
      checkin_text = "Next check-in was expected " + pretty_duration(Math.abs(time)) + " ago!";
    }
  } else if(state == 'in_session') {
    if(distress == true) {
      state_text = "Initial check-in indicated DISTRESS";
      checkin_text = ""
      progress_pct = 100;
      bar_class = "danger active";
    } else {
      state_text = "In session, initial check-in OK";
      progress_pct = (length-time) / length * 100;
      if(time >= 0) {
        bar_class = "success";
        checkin_text = "Next check-in expected in " + pretty_duration(time);
      } else {
        bar_class = "danger active";
        checkin_text = "Next check-in was expected " + pretty_duration(Math.abs(time)) + " ago!";
      }
    }
  } else {
    state_text = "Unknown";
    checkin_text = ""
    progress_pct = 0;
    bar_class = "success";
  }
  document.getElementById('session_state').innerHTML = state_text;
  document.getElementById('time_until_checkin').innerHTML = checkin_text;
  document.getElementById('session_progress_bar').style.cssText = "width: " + progress_pct + "%;";
  document.getElementById('session_progress').className = "progress progress-" + bar_class + " progress-striped";
}

var ws;
var last_status;
var last_comms = -1;
function connectWebservice() {
    ws = new WebSocket('ws://' + window.location.host + window.location.pathname);
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
      set_session_info(last_status.session_state, last_status.session_distress, last_status.time_until_checkin, last_status.session_length);
      $('#location_text').html("Location: " + last_status.location);
      last_comms = 0; 
    };
}

function sendLocationUpdate(location, token) {
  var updateMsg = {};
  updateMsg['location'] = location;
  updateMsg['token'] = token;
  ws.send(JSON.stringify(updateMsg));
}

window.onload = function() {
  connectWebservice();
  
  // timer to update the UI once a second
  setInterval(function() {
    if(!last_status) { return; }
    last_status.time_until_checkin--;
    set_session_info(last_status.session_state, last_status.session_distress, last_status.time_until_checkin, last_status.session_length);
    last_comms++;
    set_last_comms(last_comms);
  }, 1000);
  
  // timer to reconnect if we get disconnected
  setInterval(function() {
    if(ws.readyState == 3) {
      console.log("Reconnecting to webservice");
      connectWebservice();
    }
  }, 5000);
}
