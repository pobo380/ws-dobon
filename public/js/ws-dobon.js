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
      buttons: { OK: function() {
        $(this).dialog("close");
        if(callback != undefined) { callback(); }
      }}
    });
  };

  var update_hand = function(deck) {
    html = '';
    for(var idx = 0; idx < deck.length; ++idx) {
      pos = string2image(deck[idx]);
      html = html + '<div class="playing_card_img" style="background-position:' + 
             [pos.x, pos.y].join('px ') + 'px">'+ deck[idx] + '</div>';
    }
    $("#hand").html(html);
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

  /** playing cards: string to image
   */
  var string2image = function(str) {
    var pos  = {x:0, y:0};
    var size = {w:258, h: 348}
    suit = str.charAt(0);

    rate = 0;
    switch(suit) {
      case 'H':
        rate = 0; break;
      case 'C':
        rate = 1; break;
      case 'D':
        rate = 2; break;
      case 'S':
        rate = 3; break;
      case 'F':
        break;
    }
    pos.y = (size.h + 7) * rate * -1;

    num = str.charAt(1);
    rate = 0;
    num_list = [
      '1', '2', '3', '4',
      '5', '6', '7', '8',
      '9', '0', 'J', 'Q', 'K'
    ];
    for(var i = 0; i < num_list.length; ++i) {
      if(num_list[i] == num) {
        rate = i;
        break;
      }
    }
    pos.x = (size.w + 7) * rate * -1;

    return pos;
  }

  /** call ws-dobon APIs
   */
  var call_api = function(url, data, ok) {
    $.getJSON(url, data, function(json) {
      if(json.status == "NG") {
        show_dialog(json.message);
      }
      else {
        ok(json.message);
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

  /** Update screen
   */
  if(player_data != null) {
    show_game_table();
  }
});
