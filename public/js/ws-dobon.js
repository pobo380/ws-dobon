/**
 * ws-dobon.js
 * @author pobo380
 */
$(function() {
  $("#create_room, #join_room").button();
  $("#room_list").selectable();

  /**
   */
  var show_dialog = function(msg) {
    $("#dialog-message").text(msg);
    $("#dialog-message").dialog({
      modal: true,
      buttons: { Ok: function() {
        $(this).dialog("close");
      }}
    });
  };

  /** call ws-dobon APIs
   */
  var call_api = function(url, data, ok) {
    $.getJSON(url, data, function(json) {
      if(json[0] == "NG") {
        show_dialog(json[1]);
      }
      else {
        ok(json[1]);
      }
    });
  };

  $("#create_room").bind('click', function() {
    call_api("room/create",
             { name: $("#room_name").val() },
             function(msg) {
               show_dialog(msg);
             });
  });


  $("#join_room").bind('click', function() {
    call_api("player/join",
             { name:    $("#player_name").val(),
               room_id: $(".ui-selected span").attr("value") },
             function(msg){
               show_dialog(msg);
             });
  });
});
