Sequel.migration do
  up do
    require File.expand_path(File.dirname(__FILE__)) + '/../ws-dobon'

    # GameState
    ['dobon', 'agari', 'miss-dobon', 'make'].each do |e|
      Models::FinishType.create(:label => e)
    end

    ['ready', 'not-ready', 'inactive'].each do |e|
      Models::PlayerState.create(:label => e)
    end

    ['wait-to-play', 'wait-to-dobon'].each do |e|
      Models::RoundState.create(:label => e)
    end
  end

  down do
    ##TODO
  end
end
