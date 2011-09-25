Sequel.migration do
  up do
    ## create table for Jinro::Model::GameStatus
    create_table :game_states do
      primary_key :id
      String :label, :text => true
      DateTime :created_at
    end

    ## create table for Jinro::Model::Role
    create_table :roles do
      primary_key :id
      String :label, :text => true
      DateTime :created_at
    end

    ## create table for Jinro::Model::Ability
    create_table :abilities do
      primary_key :id
      String :label, :text => true
      DateTime :created_at
    end

    ## create table for Jinro::Model::Phase
    create_table :phases do
      primary_key :id
      String :label, :text => true
      DateTime :created_at
    end

    ## create table for Jinro::Model::Village
    create_table :villages do
      primary_key :id
      foreign_key :phase_id, :phases
      foreign_key :game_state_id, :game_states
      String   :name, :text => true
      DateTime :created_at
      Integer  :day, :unsigned => true
      Integer  :conversation_timelimit, :unsigned => true
      Integer  :vote_timelimit, :unsigned => true
      Integer  :howl_timelimit, :unsigned => true
      Integer  :action_timelimit, :unsigned => true
      String   :password, :text => true
    end

    ## create table for Jinro::Model::Villager
    create_table :villagers do
      primary_key :id
      foreign_key :village_id, :villages
      foreign_key :role_id, :roles
      String    :handlename, :text => true
      String    :charactorname, :text => true
      String    :loginkey, :text => true
      TrueClass :alive
      DateTime  :created_at
    end

    ## create table for Jinro::Model::Action
    create_table :actions do
      primary_key :id
      foreign_key :origin_id,  :villagers
      foreign_key :target_id,  :villagers
      foreign_key :ability_id, :abilities
      Integer     :day, :unsigned => true
      foreign_key :phase_id, :phases
      DateTime :created_at
    end

    ## create table for Jinro::Model::Conversation
    create_table :conversations do
      primary_key :id
      foreign_key :villager_id, :villagers
      String      :text, :text => true
      Integer     :day, :unsigned => true
      foreign_key :phase_id, :phases
      DateTime    :created_at
    end
  end

  down do
    [
      :conversations, :actions, :villagers, :villages,
      :phases, :abilities, :roles, :game_states
    ].each do |table|
      drop_table(table)
    end
  end
end
