/**
 * ws-dobon.js
 * @author pobo380
 */

var UI = {

  /**
   * Audio methods
   */
  "audio" : {

    // -------------------------------------------
    // Load audio resources.
    // -------------------------------------------
    "load" : function(sounds) {
      var ext = "";
      if((new Audio("")).canPlayType("audio/ogg") != "") {
        ext = ".ogg";
      }
      else {
        ext = ".wav";
      }

      var res = {};
      for(var key in sounds) {
        res[key] = new Audio("../sound/" + sounds[key] + ext);
        res[key].autoplay = false;
      }

      return res;
    },
  },


  /**
   * Update screen methods.
   */
  "update" : {

    // -------------------------------------------
    // update round number.
    // -------------------------------------------
    "round" : function(num) {
      $("#round_number").text(num.toString());
    },

    // -------------------------------------------
    // update played_card
    // -------------------------------------------
    "played" : function(card) {
      pos = this.utils.card_string2image(card);
      $("#played_card").css("background-position", [pos.x, pos.y].join('px '));
    },

    // -------------------------------------------
    // update others infomation.
    // -------------------------------------------
    "others" : function(others) {
      var player_idx;
      for(player_idx = 0; player_idx < others.length; ++player_idx) {
        if(others[player_idx].id == player.id) {
          break;
        }
      }

      var others_names  = $(".other_name");
      //var other_scores = $(".other_score");
      var others_hands   = $(".other_hand");
      for(var idx = (player_idx+1)%others.length; idx != player_idx; idx = (idx+1)%others.length) {
        $(others_names[idx]).text(others[idx].name);
        $(others_hands[idx]).text(others[idx].hand);
      }
    },

    // -------------------------------------------
    // update Player's hand.
    // -------------------------------------------
    "hand" : function(deck) {
      html = '';
      for(var idx = 0; idx < deck.length; ++idx) {
        pos = this.utils.card_string2image(deck[idx]);
        html = html + '<li class="playing_card_img ui-widget-content" style="background-position:' + 
               [pos.x, pos.y].join('px ') + 'px"' + 'value="'+ deck[idx] +'"></li>';
      }
      $("#hand").html(html);
      $("#hand").selectable();
    },

    // -------------------------------------------
    // show table
    // -------------------------------------------
    "show_table" : function() {
      $("#create_room_container, #room_list_container")
        .hide(1500);
      $("#game_table_container")
        .show(1500);
      $("#game_ready").attr("disabled", false);
    },

    /**
     * Utilities to update screen.
     */
    "utils" : {

      // -------------------------------------------
      // card_string2image
      // -------------------------------------------
      "card_string2image" : function(str) {
        var pos  = {x:0, y:0};
        var size = {w:56, h: 80}
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
        pos.y = (size.h + 0) * rate * -1;

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
        pos.x = (size.w + 0) * rate * -1;

        return pos;
      },
    },
  },


  /**
   * Methods to call ws-dobon APIs
   */
  "ajax" : {
    // -------------------------------------------
    // Simple HTTP GET : Show error dialog when server responded NG.
    // -------------------------------------------
    "simple_get" : function(url, data, ok) {
      $.getJSON(url, data, function(json) {
        if(json.status == "NG") {
          UI.show_dialog(json.message);
        }
        else {
          ok(json.message);
        }
      });
    },
  },

  // -------------------------------------------
  // Show server message dialog.
  // -------------------------------------------
  "show_dialog" : function(msg, callback) {
    $("#dialog-message").text(msg);
    $("#dialog-message").dialog({
      modal: true,
      buttons: { OK: function() {
        $(this).dialog("close");
        if(callback != undefined) { callback(); }
      }}
    });
  },

  // -------------------------------------------
  // bind Pusher events.
  // -------------------------------------------
  "bind_pusher_events" : function(pusher, room_id) {
    var channel = pusher.subscribe(room_id.toString());

    /**
     * bind Pusher events
     */
    channel.bind('ready', function(data) {
      console.log('received:' + JSON.stringify(data));
    });

    channel.bind('deal', function(data){
      console.log('received:' + JSON.stringify(data));
      UI.update.played(data.played);
      UI.update.round(data.round);
      UI.update.others(data.others);
      $.getJSON("player/action/hand", function(hand){
        UI.update.hand(hand);
      });
    });
  },

};

/**
 *
 */
$(function() {

  /**
   * Load audio resources
   */
  var sounds = {click: "button16"};
  sounds = UI.audio.load(sounds);

  /**
   * UI Initialize
   */
  $("#create_room, #join_room, #game_ready, #game_play, #game_dobon, #game_pass").button();
  $("#room_list").selectable();
  $("#game_table_container").hide();

  /**
   * Pusher
   */
  var pusher  = new Pusher('cb41fd71f6794c98a6a6');

  /** Bind events
   */
  $("#create_room").bind('click', function() {
    UI.ajax.simple_get("room/create",
                       { name: $("#room_name").val() },
      function(msg) {
        UI.show_dialog(msg, function(){
          location.reload();
        });
      });
  });

  $("#join_room").bind('click', function() {
    $.getJSON("player/join",
              { name:    $("#player_name").val(),
                room_id: $(".ui-selected span").attr("value") },
      function(data) {
        $.getJSON("player/self",{}, function(player){
          window.player = player; ## 
        });
        UI.bind_pusher_events(pusher, data.room_id);
        UI.update.show_table();
      });
  });

  $("#game_ready").bind('click', function() {
    game_ready = $("#game_ready");
    game_ready.attr("disabled", true);
    UI.ajax.simple_get("player/ready", {},
                       function(msg){
                       });
  });

  // メニュー選択時のクリック音
  $("#create_room_container .menu-title a").bind("click", function() {
    sounds.click.play();
    $(this).parent().next().toggle(500);
    $("#room_list_container").slideDown(500);
  });

  /**
   * 入室しているかどうか
   */
  if(player != null) {
    UI.bind_pusher_events(pusher, player.room_id);

    UI.update.show_table();
    if(player.hand != "") {
      UI.update.hand(player.hand.split(","));
    }
    console.log("入室済み");
  }
  else {
    console.log("入室していない");
  }
});
