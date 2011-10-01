/**
 * ws-dobon.js
 * @author pobo380
 */
$(function() {
  /** UI Initialize
   */
  $("#create_room, #join_room, #game_ready, #game_play, #game_dobon").button();
  $("#room_list").selectable();
  $("#game_table_container").hide();

  /** UI update methods
   */
  var show_dialog = function(msg, callback) {
    $("#dialog-message").text(msg);
    $("#dialog-message").dialog({
      modal: true,
      buttons: { Ok: function() {
        $(this).dialog("close");
        if(callback != undefined) { callback(); }
      }}
    });
  };

  var update_hand = function(deck) {
    $("#your_hand").text(deck.join(', '));
  };

  var update_players = function(order) {
    $("#players").text(order.join(', '));
  };

  var update_played = function(played) {
    $("#played").text(played[0]);
  };

  var show_game_table = function() {
    $("#create_room_container, #room_list_container")
      .hide(200);
    $("#game_table_container")
      .show(500);
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

  /** Bind events
   */
  $("#create_room").bind('click', function() {
    call_api("room/create",
             { name: $("#room_name").val() },
             function(msg) {
               show_dialog(msg, function(){
                 location.reload();
               });
             });
  });


  $("#join_room").bind('click', function() {
    call_api("player/join",
             { name:    $("#player_name").val(),
               room_id: $(".ui-selected span").attr("value") },
             function(msg) {
               show_game_table();
             });
  });

  $("#game_ready").bind('click', function() {
    game_ready = $("#game_ready");
    val = game_ready.attr("value");
    call_api("player/" + val, {},
             function(msg) {
               if(val == 'ready') {
                 game_ready.attr('value', 'not-ready');
               }
               else {
                 game_ready.attr('value', 'ready');
               }
               game_ready.attr("disabled", true);
               $.getJSON("/player/action/hand", 
                          function(json) {
                            update_hand(json);
                          });
               $.getJSON("/player/action/players", 
                          function(json) {
                            update_players(json);
                          });
               $.getJSON("/player/action/played", 
                          function(json) {
                            update_played(json);
                          });
             });
  });
});
