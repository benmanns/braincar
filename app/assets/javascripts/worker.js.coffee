#= require brain/brain-0.6.0

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

train = (message) ->
  data = message.data
  trainData = ({input: inputFrom(datum, message), output: datum.controls} for datum in data)
  net = new brain.NeuralNetwork
    hiddenLayers: [7, 7]
  e = net.train trainData,
    callback: (e) ->
      @postMessage
        command: 'status'
        data: e
    callbackPeriod: 1000
  @postMessage
    command: 'finished'
    data:
      e: e
      network: net.toJSON()

@addEventListener('message', (e) ->
  if e.data.command == 'train'
    train(e.data)
, false)

