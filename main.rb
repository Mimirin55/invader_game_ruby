require 'gosu'

class GameWindow < Gosu::Window
  def initialize
    @game_state = :playing
    super 640, 480
    self.caption = "Invader Game Ruby"
    @ship = Ship.new
    @invaders = []
    @invader_direction = 1
    @invader_speed = 1
    @shots = []
    @explosions = []
    @score = 0

    11.times do |i|
      x = 50 + i * 50

      [0, 3].each do |row|
        y = 50 + row * 40
        @invaders << Invader.new(x, y, INVADER_1_SPRITE, Gosu::Color::GREEN)
      end

      [1, 4].each do |row|
        y = 50 + row * 40
        @invaders << Invader.new(x, y, INVADER_2_SPRITE, Gosu::Color::FUCHSIA)
      end

      [2, 5].each do |row|
        y = 50 + row * 40
        @invaders << Invader.new(x, y, INVADER_3_SPRITE, Gosu::Color::YELLOW)
      end
    end
  end

  def draw
    @ship.draw
    @invaders.each(&:draw)
    @shots.each(&:draw)
    @explosions.each(&:draw)
    draw_score

    if @game_state == :game_over
      Gosu.draw_rect(0, 0, 640, 480, Gosu::Color::BLACK, 10)
      DotTextOver.new("GAME OVER", 640 / 2, 200, Gosu::Color::YELLOW).draw
    end

    if @game_state == :game_clear
      Gosu.draw_rect(0, 0, 640, 480, Gosu::Color::BLACK, 10)
      DotTextClear.new("GAME CLEAR", 640 / 2, 200, Gosu::Color::AQUA).draw
    end
  end

  def update
    edge_reached = false

    @invaders.each do |inv|
      inv.move(@invader_direction * @invader_speed, 0)
      # 端っこ判定
      edge_reached ||= (inv_right(inv) >= 640 || inv_left(inv) <= 0)
    end

    if edge_reached
      @invader_direction *= -1
      @invaders.each { |inv| inv.move(0, 10) }
    end

    @ship.move_left if Gosu.button_down?(Gosu::KB_LEFT)
    @ship.move_right if Gosu.button_down?(Gosu::KB_RIGHT)

    if Gosu.button_down?(Gosu::KB_SPACE)
      if @shots.empty? || @shots.last.y < @ship.shot_origin[1] - 30
        x, y = @ship.shot_origin
        @shots << Shot.new(x, y)
      end
    end

    @shots.each(&:update)
    @shots.reject!(&:off_screen?)

    @shots.each do |shot|
      @invaders.delete_if do |inv|
        if shot.hit?(inv)
          cx = inv.x + inv.width / 2
          cy = inv.y + inv.height / 2
          @explosions << Explosion.new(cx, cy)
          @score += 10
          true
        else
          false
        end
      end
    end

    @explosions.each(&:update)
    @explosions.reject!(&:done?)

    def draw_score
      font = Gosu::Font.new(24)
      font.draw_text("Score: #{@score}", 10, 10, 10, 1, 1, Gosu::Color::WHITE)
    end

    if @game_state == :playing
      @invaders.each do |inv|
        if inv.y + inv.height >= @ship.y
          @explosions << Explosion.new(@ship.x + @ship.width / 2, @ship.y)
          @game_state = :game_over
          break
        end
      end

      if @invaders.empty?
        @game_state = :game_clear
      end
    end
  end

  def inv_left(inv)
    inv.instance_variable_get(:@x)
  end

  def inv_right(inv)
    inv_left(inv) + 8 * Invader::SIZE
  end

  def collide?(a, b)
    ax1, ay1 = a.x, a.y
    ax2, ay2 = a.x + a.width, a.y + a.height
    bx1, by1 = b.x, b.y
    bx2, by2 = b.x + b.width, b.y + b.height

    !(ax2 < bx1 || ax1 > bx2 || ay2 < by1 || ay1 > by2)
  end

  def draw_text_center(text, size, color)
    font = Gosu::Font.new(size)
    text_width = font.text_width(text)
    font.draw_text(text, (640 - text_width) / 2, 220, 11, 1, 1, color)
  end
end

class Ship
  def initialize
    @x = 640 / 2 - 30
    @y = 480 - 30
    @width = 60
    @height = 20
    @cockpit_size = 20
  end

  attr_reader :x, :y, :width, :height

  def move_left
    @x -= 8 unless @x - 8 <= 0 
  end 

  def move_right
    @x += 8 unless @x + 8 >= 640 - @width
  end

  def draw
    Gosu.draw_rect(@x, @y, @width, @height, Gosu::Color::CYAN, 0)

    cockpit_x = @x + (@width - @cockpit_size) / 2
    cockpit_y = @y - @cockpit_size
    Gosu.draw_rect(cockpit_x, cockpit_y, @cockpit_size, @cockpit_size, Gosu::Color::CYAN, 0)
  end

  def shot_origin
    [@x + @width / 2 - 2, @y - 10]
  end
end

  INVADER_1_SPRITE = [
  "0001111000",
  "0011111100",
  "0110110110",
  "0110110110",
  "0111111110",
  "0001001000",
  "0010110100",
  "0101001010"
]

INVADER_2_SPRITE = [
  "0010000100",
  "0001001000",
  "0011111100",
  "0110110110",
  "0110110110",
  "0011111100",
  "0001001000",
  "0010000100"
]

INVADER_3_SPRITE = [
  "0011111100",
  "0111111110",
  "0101111010",
  "1110110111",
  "0111111110",
  "1000110001",
  "0100000010"
]

class Invader
  SIZE = 3
  WIDTH = 10 * SIZE
  HEIGHT = 8 * SIZE

  attr_reader :x, :y, :width, :height

  def initialize(x, y, sprite, color)
    @x = x
    @y = y
    @width = WIDTH
    @height = HEIGHT
    @sprite = sprite
    @color = color
  end

  def draw
    @sprite.each_with_index do |row, dy|
      row.chars.each_with_index do |pixel, dx|
        if pixel == "1"
          Gosu.draw_rect(
            @x + dx * SIZE,
            @y + dy * SIZE,
            SIZE,
            SIZE,
            @color,
            0
          )
        end
      end
    end
  end

  def move(dx, dy)
    @x += dx
    @y += dy
  end
end

class Shot
  SPEED = 10
  WIDTH = 4
  HEIGHT = 4

  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def update
    @y -= SPEED
  end

  def draw
    Gosu.draw_rect(@x, @y, WIDTH, HEIGHT, Gosu::Color::YELLOW, 0)
  end

  def off_screen?
    @y + HEIGHT < 0
  end

  def hit?(invader)
    sx, sy, sw, sh = @x, @y, WIDTH, HEIGHT
    ix, iy, iw, ih = invader.x, invader.y, invader.width, invader.height

    sx < ix + iw && sx + sw > ix && sy < iy + ih && sy + sh > iy
  end
end

class Explosion
  SIZE = 2
  FRAME_COUNT = 15  # 爆発が続くフレーム数

  def initialize(x, y)
    @x = x
    @y = y
    @frames_left = FRAME_COUNT
  end

  def update
    @frames_left -= 1
  end

  def draw
    color = Gosu::Color.rgba(rand(255), rand(255), rand(255), 255)
    10.times do
      dx = rand(-10..10)
      dy = rand(-10..10)
      Gosu.draw_rect(@x + dx, @y + dy, SIZE, SIZE, color, 1)
    end
  end

  def done?
    @frames_left <= 0
  end
end

class DotTextOver
  SIZE = 4

  CHARSET = {
    "G" => [
      "01110",
      "10000",
      "10000",
      "10011",
      "10001",
      "10001",
      "01110"
    ],
    "A" => [
      "00100",
      "01010",
      "10001",
      "11111",
      "10001",
      "10001",
      "10001"
    ],
    "M" => [
      "10001",
      "11011",
      "10101",
      "10101",
      "10001",
      "10001",
      "10001"
    ],
    "E" => [
      "11111",
      "10000",
      "10000",
      "11110",
      "10000",
      "10000",
      "11111"
    ],
    "O" => [
      "01110",
      "10001",
      "10001",
      "10001",
      "10001",
      "10001",
      "01110"
    ],
    "V" => [
      "10001",
      "10001",
      "10001",
      "10001",
      "01010",
      "01010",
      "00100"
    ],
    "R" => [
      "11110",
      "10001",
      "10001",
      "11110",
      "10100",
      "10010",
      "10001"
    ],
    " " => [
      "00000",
      "00000",
      "00000",
      "00000",
      "00000",
      "00000",
      "00000"
    ]
  }

  def initialize(text, center_x, y, color)
    @text = text.upcase
    @y = y
    @color = color

    char_width = 6  # 文字幅（5ドット+スペース）
    total_width = @text.length * char_width * SIZE
    @x = center_x - total_width / 2
  end

  def draw
    @text.chars.each_with_index do |char, i|
      bitmap = CHARSET[char] || CHARSET[" "]
      bitmap.each_with_index do |row, dy|
        row.chars.each_with_index do |bit, dx|
          if bit == "1"
            Gosu.draw_rect(
              @x + (i * 6 + dx) * SIZE,
              @y + dy * SIZE,
              SIZE,
              SIZE,
              @color,
              11
            )
          end
        end
      end
    end
  end
end

class DotTextClear
  SIZE = 4

  CHARSET = {
    "G" => [
      "01110",
      "10000",
      "10000",
      "10011",
      "10001",
      "10001",
      "01110"
    ],
    "A" => [
      "00100",
      "01010",
      "10001",
      "11111",
      "10001",
      "10001",
      "10001"
    ],
    "M" => [
      "10001",
      "11011",
      "10101",
      "10101",
      "10001",
      "10001",
      "10001"
    ],
    "E" => [
      "11111",
      "10000",
      "10000",
      "11110",
      "10000",
      "10000",
      "11111"
    ],
    "C" => [
      "11111",
      "10001",
      "10000",
      "10000",
      "10000",
      "10001",
      "01110"
    ],
    "L" => [
      "10000",
      "10000",
      "10000",
      "10000",
      "10000",
      "10000",
      "11111"
    ],
    "R" => [
      "11110",
      "10001",
      "10001",
      "11110",
      "10100",
      "10010",
      "10001"
    ],
    " " => [
      "00000",
      "00000",
      "00000",
      "00000",
      "00000",
      "00000",
      "00000"
    ]
  }

  def initialize(text, center_x, y, color)
    @text = text.upcase
    @y = y
    @color = color

    char_width = 6  # 文字幅（5ドット+スペース）
    total_width = @text.length * char_width * SIZE
    @x = center_x - total_width / 2
  end

  def draw
    @text.chars.each_with_index do |char, i|
      bitmap = CHARSET[char] || CHARSET[" "]
      bitmap.each_with_index do |row, dy|
        row.chars.each_with_index do |bit, dx|
          if bit == "1"
            Gosu.draw_rect(
              @x + (i * 6 + dx) * SIZE,
              @y + dy * SIZE,
              SIZE,
              SIZE,
              @color,
              11
            )
          end
        end
      end
    end
  end
end

window = GameWindow.new
window.show
