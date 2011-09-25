Sequel.migration do
  up do
    require File.expand_path(File.dirname(__FILE__)) + '/../ws-dobon'

    # GameState
    ['dobon', 'agari'].each do |e|
      Models::FinishType.create(:label => e)
    end
  end

  down do
    ##TODO
  end
end
