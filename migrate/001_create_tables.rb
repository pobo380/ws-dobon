Sequel.migration do
  up do
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

    ## create table for Model::GameResult
    create_table :game_results do
      primary_key :id
      foreign_key :game_id, :games
      foreign_key :player_id, :players

      Integer :rank
      DateTime :created_at
    end

    ## create table for Model::Round
    create_table :rounds do
      primary_key :id
      foreign_key :game_id, :games
      foreign_key :winner_id, :players
      foreign_key :loser_id,  :players

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

    ## create table for Model::Player
    create_table :players do
      primary_key :id
      foreign_key :room_id, :rooms

      String    :name, :text => true
      String    :hand, :text => true
      TrueClass :is_ready
      DateTime :created_at
    end

    ## create table for Model::FinishType
    create_table :finish_types do
      primary_key :id

      String :label, :text => true
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
