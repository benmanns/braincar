# This is a manifest file that'll be compiled into application.js, which will include all the files
# listed below.
#
# Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
# or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
#
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# the compiled file.
#
# WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
# GO AFTER THE REQUIRES BELOW.
#
#= require jquery
#= require jquery_ujs
#= require numeric/numeric-1.2.6
#= require brain/brain-0.6.0

$ ->
  $canvas = $('#brain-car')
  context = $canvas.get(0).getContext('2d')
  $instructions = $('#instructions')
  width = $canvas.width()
  height = $canvas.height()

  drawCourse = ->
    context.fillStyle = 'rgba(0, 0, 0, 1)'
    context.fillRect(0, 0, width, height)

    context.fillStyle = 'rgba(255, 0, 0, 1)'
    context.beginPath()
    context.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2, true)
    context.closePath()
    context.fill()

    context.fillStyle = 'rgba(0, 0, 0, 1)'
    context.beginPath()
    context.arc(width / 2, height / 2, Math.min(width, height) / 4, 0, Math.PI * 2, true)
    context.closePath()
    context.fill()

    context.strokeStyle = 'rgba(0, 0, 0, 1)'
    context.beginPath()
    context.arc(width / 2, height / 2, 3 * Math.min(width, height) / 8, 0, Math.PI * 2, true)
    context.closePath()
    context.stroke()

  class Car
    position: [0, 0]
    velocity: [0, 0]
    acceleration: [0, 0]
    theta: 0
    controls: [0, 0, 0, 0]
    width: 10
    height: 20
    Object.defineProperty @prototype, 'left'
      get: -> @controls[0]
      set: (value) -> @controls[0] = value
    Object.defineProperty @prototype, 'right'
      get: -> @controls[1]
      set: (value) -> @controls[1] = value
    Object.defineProperty @prototype, 'forward'
      get: -> @controls[2]
      set: (value) -> @controls[2] = value
    Object.defineProperty @prototype, 'reverse'
      get: -> @controls[3]
      set: (value) -> @controls[3] = value
    draw: (context) ->
      context.save()
      context.translate(@position[0] + (@width / 2), @position[1] + (@height / 2))
      context.rotate(@theta)
      context.fillStyle = 'rgba(0, 255, 0, 0.5)'
      context.fillRect(-(@width / 2), -(@height / 2), @width, @height)
      context.beginPath()
      context.moveTo(0, 0)
      context.lineTo(0, @height)
      context.stroke()
      context.restore()
    move: ->
      if driving and not training
        data.push
          position: @position.slice(0)
          velocity: @velocity.slice(0)
          acceleration: @acceleration.slice(0)
          theta: @theta
          controls: @controls.slice(0)
        if data.length < 100
          $instructions.text("Keep driving! #{data.length}/100 points collected.")
        else
          $instructions.text("#{data.length} points collected. Press T to train.")
      @theta += 0.3 * (@right - @left)
      @theta %= 2 * Math.PI
      @acceleration = [Math.sin(-@theta) * (@forward - @reverse) * 10, Math.cos(-@theta) * (@forward - @reverse) * 10]
      numeric.addeq(@acceleration, numeric.mul(@velocity, -0.01 * numeric.norm2(@velocity)))
      numeric.addeq(@acceleration, numeric.mul(@velocity, -0.2))
      # I know, I know - I should be using RK4.
      numeric.addeq(@velocity, @acceleration)
      numeric.addeq(@position, @velocity)
    reset: (position = true) ->
      @position = [3 * width / 4, height / 2] if position
      @velocity = [0, 0]
      @acceleration = [0, 0]
      @controls = [0, 0, 0, 0]

  car = new Car
  car.reset()

  data = []

  tick = ->
    car.move()
    drawCourse()
    car.draw(context)

  setInterval(tick, 100)

  $instructions.text('Begin driving with WASD or ↑←↓→.')
  driving = false
  training = false

  net = new brain.NeuralNetwork()

  inputFrom = (datum, constraints) ->
    [
      datum.position[0] / constraints.width
      datum.position[1] / constraints.height
      Math.pow(datum.position[0] / constraints.width, 2)
      Math.pow(datum.position[1] / constraints.height, 2)
      datum.velocity[0] / 30
      datum.velocity[1] / 30
      datum.acceleration[0] / 30
      datum.acceleration[1] / 30
      datum.theta / (2 * Math.PI)
      Math.sin(datum.theta)
      Math.cos(datum.theta)
    ]

  worker = new Worker('/assets/worker.js')
  worker.addEventListener('message', (e) ->
    if e.data.command == 'status'
      $instructions.text("Training iterations: #{e.data.data.iterations}, error: #{(e.data.data.error * 100).toFixed(2)}%")
    else if e.data.command = 'finished'
      $instructions.text("Training done: iterations: #{e.data.data.e.iterations}, error #{(e.data.data.e.error * 100).toFixed(2)}%. Press R to run.")
      net.fromJSON(e.data.data.network)
  , false)

  run = ->
    output = net.run(inputFrom(car, {width: width, height: height}))
    car.controls = (x > 0.50 ? 1 : 0 for x in output)
  running = undefined

  $(window).keydown (e) ->
    switch e.which
      when 37, 65 # left, A
        car.left = 1
        driving = true
      when 38, 87 # up, W
        car.forward = 1
        driving = true
      when 39, 68 # right, D
        car.right = 1
        driving = true
      when 40, 83 # down, S
        car.reverse = 1
        driving = true
      when 84 # T
        training = true
        worker.postMessage
          command: 'train'
          data: data
          width: width
          height: height
        $instructions.text('Starting training.')
      when 82 # R
        if running
          clearInterval(running)
          running = undefined
          position =
            car.position[0] < 0 or
            car.position[0] >= width or
            car.position[0] < 0 or
            car.position[1] >= height
          car.reset(position)
          $instructions.text('Running stopped. Press R to run.')
        else
          running = setInterval(run, 100)
          $instructions.text('Running. Press R to stop.')
      else
        console.log("Pressed #{e.which}.")

  $(window).keyup (e) ->
    switch e.which
      when 37, 65 # left, A
        car.left = 0
      when 38, 87 # up, W
        car.forward = 0
      when 39, 68 # right, D
        car.right = 0
      when 40, 83 # down, S
        car.reverse = 0
