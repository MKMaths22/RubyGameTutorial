class Game
  SLEEP_INTERVAL = 0.5

  def run
    @screen = Screen.new
    
    @level = LevelBuilder.new("./map.txt").build
    
    loop do
      sleep SLEEP_INTERVAL
      @screen.render_level(@level)
      
      @level.explosions = []
      
      break if move_enemies == 'game_over'
      move_fireballs

      new_player_position = DynamicObject.new(@level.player.row_idx, @level.player.col_idx, :player)
      
      key = get_pressed_key
      if key == SPACE_BAR
        make_fireball(@level.player)
        next
        # no need to run check_collision because player did not move. When move_enemies was done above, collisions were checked
      else 
        new_player_position.move(key)
      end

      case check_collision(new_player_position.row_idx, new_player_position.col_idx, @level.enemies + [@level.door])
      when :door
        @screen.render_level_passed_message
        break
      when :enemy
        @screen.render_death_message
        break
      when nil
        @level.player = new_player_position
      end
    end
  end

  private

  def make_fireball(player)
    # puts "A fireball is under construction LOL"
    # new_fireball = DynamicObject.new(player.row_idx, player.col_idx, :fireball, [LEFT, RIGHT, UP, DOWN].sample)
    new_fireball = DynamicObject.new(player.row_idx, player.col_idx, :fireball, UP)
    # puts "The fireball is #{new_fireball}"
    new_fireball.move(new_fireball.direction)
    # puts "Now the fireball is #{new_fireball}"
    if check_collision(new_fireball.row_idx, new_fireball.col_idx, [@level.door])
      new_explosion = DynamicObject.new(player.row_idx, player.col_idx, :explosion)
      @level.explosions << new_explosion
      # fireballs CANNOT hit the player, so the explosion coincides with the player to show they made a fireball that couldn't go anywhere
      @screen.render_level(@level)
      return
    end
    # intial check_collision just checks for out_of_border or tree, enemies do not destroy the fireball because it keeps going
    # enemies can coincide with each other, and the fireball will kill ALL enemies on that spot before potentially continuing and killing more or colliding with a tree/border of the map
    # need to remove ALL enemy from @level.enemies that has those coords.
    # Maybe give those enemies off-grid coordinates instead of removing them, which means the rest of the array doesn't need to be shifted
    @level.fireballs << new_fireball
    @level.enemies.each do |enemy|
      enemy.row_idx, enemy.col_idx = 0.5, 0.5 if enemy.row_idx == new_fireball.row_idx && enemy.col_idx == new_fireball.col_idx
    end
    # make fireballs move after enemies move, with collision detection for fireballs, and for enemies with fireballs
    # fireballs only turn into one-frame explosions at trees or border of the map, otherwise they kill enemies or travel without exploding
  end
  
  def check_collision(row_idx, col_idx, objects)
    return :out_of_border if row_idx < 0 || row_idx >= @level.map.length || col_idx < 0 || col_idx >= @level.map[0].length
    return :tree if @level.map[row_idx][col_idx] == TREE
    objects.find { _1.row_idx == row_idx && _1.col_idx == col_idx }&.kind
  end
  
  def get_pressed_key
    begin
      system('stty raw -echo')
      (STDIN.read_nonblock(4).ord rescue nil)
    ensure
      system('stty -raw echo')
    end
  end
  
  def move_enemies
    @level.enemies.each_with_index do |enemy, idx|
      next if (rand(1) > 0.8 || enemy.row_idx == 0.5)
      new_enemy = DynamicObject.new(enemy.row_idx, enemy.col_idx, :enemy)
      new_enemy.move([RIGHT, LEFT, UP, DOWN].sample)
      hit_anything = check_collision(new_enemy.row_idx, new_enemy.col_idx, @level.fireballs + [@level.door, @level.player])
      @level.enemies[idx] = new_enemy unless hit_anything
      case hit_anything
      when :player
        @screen.render_death_message
        return 'game_over'
      when :fireball
        @level.enemies[idx].row_idx, @level.enemies[idx].col_idx = 0.5, 0.5
      end
    end
  end

  def move_fireballs
    # puts "The move_fireballs method is running. The fireballs are #{@level.fireballs}."
    # sleep(2)
    @level.fireballs.each_with_index do |fireball, idx|
      next if fireball.row_idx == 0.5
      new_fireball = DynamicObject.new(fireball.row_idx, fireball.col_idx, :fireball)
      new_fireball.move(fireball.direction)
      puts "The new fireball is #{new_fireball}"
      hit_anything = check_collision(new_fireball.row_idx, new_fireball.col_idx, @level.enemies + [@level.door])
        case hit_anything
        when :door, :tree, :out_of_border
          new_explosion = DynamicObject.new(fireball.row_idx, fireball.col_idx, :explosion)
          @level.explosions << new_explosion
          @level.fireballs[idx].row_idx, @level.fireballs[idx].col_idx = 0.5, 0.5
        when :enemy
          @level.enemies.each do |enemy|
            enemy.row_idx, enemy.col_idx = 0.5, 0.5 if enemy.row_idx == new_fireball.row_idx && enemy.col_idx == new_fireball.col_idx
          end
        else
          @level.fireballs[idx].row_idx, @level.fireballs[idx].col_idx = new_fireball.row_idx, new_fireball.col_idx
        end
    end
  end
end

PLAYER, ENEMY, DOOR, TREE, SPACE, FIREBALL, EXPLOSION = '🧙', '👻', '🚪', "\u{1F332}", "・", "\u{1F525}", "\u{1F4A5}"
# 🌲

UP, DOWN, RIGHT, LEFT, SPACE_BAR = 119, 115, 100, 97, 32

Level = Struct.new(:map, :enemies, :player, :door, :fireballs, :explosions)

DynamicObject = Struct.new(:row_idx, :col_idx, :kind, :direction) do
  def move(dir)
    case dir
    when RIGHT then self.col_idx += 1
    when LEFT then self.col_idx -= 1
    when UP then self.row_idx -= 1
    when DOWN then self.row_idx += 1
    end
  end
end

class LevelBuilder
  def initialize(filepath)
    @filepath = filepath
  end

  MAPPING = { 't' => TREE, 's' => SPACE }

  def build
    Level.new.tap do |level|
      level.enemies = []
      level.fireballs = []
      level.explosions = []

      level.map = File.readlines(@filepath).map.with_index do |line, row_idx|
        line.chars.map.with_index do |c, col_idx|
          case c
          when 'e'
            level.enemies << DynamicObject.new(row_idx, col_idx, :enemy)
            SPACE
          when 'p'
            level.player = DynamicObject.new(row_idx, col_idx, :player)
            SPACE
          when 'd'
            level.door = DynamicObject.new(row_idx, col_idx, :door)
            SPACE
          else
            MAPPING[c]
          end
        end
      end
    end
  end
end

class Screen
  def render_level(level)
    system "clear"
    
    level.map.each_with_index do |row, row_idx|
      row.each_with_index do |cell, col_idx|
      if level.explosions.find { |explosion| explosion.row_idx == row_idx && explosion.col_idx == col_idx }
        print EXPLOSION  
        elsif level.player.row_idx == row_idx && level.player.col_idx == col_idx
          print PLAYER
        elsif level.door.row_idx == row_idx && level.door.col_idx == col_idx
          print DOOR
        elsif level.enemies.find { |enemy| enemy.row_idx == row_idx && enemy.col_idx == col_idx }
          print ENEMY
        elsif level.fireballs.find { |fireball| fireball.row_idx == row_idx && fireball.col_idx == col_idx }
          print FIREBALL
        else
          print cell
        end
      end
      puts "\n"
    end
  end

  def render_death_message = puts "☠️ You died ☠️"
  def render_level_passed_message = puts "🎉 Level passed 🎉"
end

Game.new.run
