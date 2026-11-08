module Ofpr
  # The site's own menu, in the order and the wording the captured one has, which is
  # also what the captured page titles call each section.
  module Menu
    ITEMS = [
      {label: 'News', path: '/'},
      {label: 'Search', path: '/search'},
      {label: 'Convert',
       url: 'https://forums.bohemia.net/forums/topic/217443-ofpinfo-20/?do=findComment&comment=3414490'},
      {label: 'Addons', path: '/addons', children: [
        {label: 'Weapons', path: '/addons/weapons'},
        {label: 'Vehicles', path: '/addons/vehicles'},
        {label: 'Units', path: '/addons/units'},
        {label: 'Misc', path: '/addons/misc'},
        {label: 'Boats', path: '/addons/boats'},
        {label: 'Aircrafts', path: '/addons/aircrafts'},
        {label: 'Skins', path: '/addons/skins'},
        {label: 'Islands', path: '/addons/islands'}
      ]},
      {label: 'MODS', path: '/mods'},
      {label: 'Missions', path: '/missions', children: [
        {label: 'SinglePlayer (SP)', path: '/missions/singleplayer-sp'},
        {label: 'MultiPlayer (MP)', path: '/missions/multiplayer-mp'},
        {label: 'Campaigns', path: '/missions/campaigns'},
        {label: 'MissionPacks', path: '/missions/missionpacks'},
        {label: 'Desert Storm - missions', path: '/missions/desert-storm-missions'},
        {label: 'VideoMissions', path: '/missions/videomissions'},
        {label: 'EditorExtra', path: '/missions/editorextra'}
      ]},
      {label: 'Patches', path: '/patches'},
      {label: 'Utilities', path: '/utilities'}
    ].freeze

    # The two groups the sidebar lists, with the counts filled in by the caller.
    def self.group(label) = ITEMS.find { |item| item[:label] == label }[:children]

    # Addons and Missions hold no articles of their own; they are the two headings the
    # sections hang under, and each has a page listing them.
    def self.children_of(path)
      ITEMS.find { |item| item[:path] == path && item[:children] }&.fetch(:children)
    end

    # What leads to a path: the group and the item in it, or the single item when it
    # is not in a group. Empty when the menu does not hold the path at all.
    def self.trail(path)
      ITEMS.each do |item|
        return [item] if item[:path] == path

        child = item[:children]&.find { |each| each[:path] == path }
        return [item, child] if child
      end
      []
    end

    # What the site called a section. Joomla stored `unofaddons/vehicles`, which is
    # where the files sat on its server; the captured page titles say `Vehicles`.
    def self.label(path) = trail(path).last&.fetch(:label)

    def self.holds?(item, path)
      return true if item[:path] == path

      item[:children]&.any? { |child| child[:path] == path } || false
    end
  end
end
