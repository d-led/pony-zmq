
use "collections"
use zmq = ".."

interface iso _LambdaPartial
  fun iso apply() => None

interface iso _MessageLambdaPartial
  fun iso apply(message: zmq.Message) => None

interface iso _PeerMessageLambdaPartial
  fun iso apply(peer: zmq.SocketPeer, message: zmq.Message) => None

interface iso _MessageListLambdaPartial
  fun iso apply(message: List[zmq.Message]) => None

type _SocketReactorHandler is
  ( _MessageLambdaPartial
  | _PeerMessageLambdaPartial
  | (USize, _MessageListLambdaPartial))

actor _SocketReactor is zmq.SocketNotifiableActor
  let _messages: List[(zmq.SocketPeer, zmq.Message)] = _messages.create()
  let _handlers: List[_SocketReactorHandler]         = _handlers.create()
  
  var _closed_handler: (_LambdaPartial | None) = None
  var _closed:             Bool = false
  var _ran_closed_handler: Bool = false
  
  fun tag notify(): zmq.SocketNotify^ =>
    zmq.SocketNotifyActor(this)
  
  be next(handler: (_MessageLambdaPartial | _PeerMessageLambdaPartial)) =>
    _handlers.push(consume handler)
    maybe_run_handlers()
  
  be next_n(n: USize, handler: _MessageListLambdaPartial) =>
    _handlers.push((n, consume handler))
    maybe_run_handlers()
  
  be received(socket: zmq.Socket, peer: zmq.SocketPeer, message: zmq.Message) =>
    _messages.push((peer, message))
    maybe_run_handlers()
  
  be when_closed(handler: _LambdaPartial) =>
    _closed_handler = consume handler
    maybe_run_closed_handler()
  
  be closed(socket: zmq.Socket) =>
    _closed = true
    maybe_run_closed_handler()
  
  fun ref maybe_run_handlers() =>
    try
      while (_handlers.size() > 0) and (_messages.size() > 0) do
        match _handlers.shift()
        | let h: _MessageLambdaPartial =>
          (let peer, let message) = _messages.shift()
          (consume h)(message)
        
        | let h: _PeerMessageLambdaPartial =>
          (let peer, let message) = _messages.shift()
          (consume h)(peer, message)
        
        | (let n': USize, let h: _MessageListLambdaPartial) =>
          var n = n'
          if _messages.size() < n then _handlers.unshift((n, consume h)); error end
          
          let list = List[zmq.Message]
          while n > 0 do
            n = n - 1
            (let peer, let message) = _messages.shift()
            list.push(message)
          end
          (consume h)(list)
        end
      end
    end
  
  fun ref maybe_run_closed_handler() =>
    if _closed and not _ran_closed_handler then
      match (_closed_handler = None) | let closed_handler: _LambdaPartial =>
        (consume closed_handler)()
        _ran_closed_handler = true
      end
    end
