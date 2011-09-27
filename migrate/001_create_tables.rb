Sequel.migration do
  up do
    ## create table for Model::FinishType
    create_table :finish_types do
      primary_key :id

      String :label, :text => true
      DateTime :created_at
    end

    ## create table for Model::PlayerState
    create_table :player_states do
      primary_key :id

      String :label, :text => true
      DateTime :created_at
    end

    ## create table for Models::RoundState
    create_table :round_states do
      primary_key :id

      String :label, :text => true
      DateTime :created_at
    end

    ## create table for Model::Room
    create_table :rooms do
      primary_key :id

      String :name, :text => true
      TrueClass :is_closed
      DateTime :created_at
    end

    ## create table for Model::Game
    create_table :games do
      primary_key :id
      foreign_key :room_id, :rooms

      DateTime :created_at
    end

    ## create table for Model::Player
    create_table :players do
      primary_key :id
      foreign_key :room_id, :rooms
      foreign_key :player_state_id, :player_states

      String    :name, :text => true
      String    :hand, :text => true
      String    :sessionkey, :text => true
      DateTime :created_at
    end

    ## create table for Model::Round
    create_table :rounds do
      primary_key :id
      foreign_key :game_id, :games
      foreign_key :winner_id, :players
      foreign_key :loser_id,  :players
      foreign_key :round_state_id, :round_states

      DateTime :created_at
    end

    ## create table for Model::Table
    create_table :tables do
      primary_key :id
      foreign_key :round_id, :rounds
      foreign_key :current_player_id, :players

      String :deck,     :text => true
      String :discards, :text => true
      String :specify,  :text => true
      TrueClass :reverse
      TrueClass :restriction
      Integer :attack

      DateTime :created_at
    end

    ## create table for Model::GameResult
    create_table :game_results do
      primary_key :id
      foreign_key :game_id, :games
      foreign_key :player_id, :players

      Integer :rank
      DateTime :created_at
    end

    ## create table for Model::RoundResult
    create_table :round_results do
      primary_key :id
      foreign_key :round_id, :rounds
      foreign_key :player_id, :players
      foreign_key :finish_type_id, :finish_types

      Integer :point
      DateTime :created_at
    end

    ## create table for Model::PlayingOrder
    create_table :playing_orders do
      primary_key :key
      foreign_key :player_id, :players
      foreign_key :game_id, :games
      
      Integer :order
      DateTime :created_at
    end
  end

  down do
    [
      :rooms, :games, :game_results, :rounds,
      :round_results, :players, :finish_types
    ].each do |table|
      drop_table(table)
    end
  end
end
