
primitive _CommandParser
  fun write(command: _Command box): Array[U8] val =>
    let output = recover trn Array[U8] end
    let inner = recover trn Array[U8] end
    
    // Write name size, name, and body to inner byte array.
    let name = command.name()
    inner.push(name.size().u8())
    inner.append(name)
    inner.append(command.write_bytes())
    
    // Determine the ident and size bytewidth based on the size itself.
    let is_short = inner.size() <= 0xFF
    let ident: U8 = if is_short then 0x04 else 0x06 end
    let size      = if is_short then inner.size().u8() else inner.size() end
    
    // Write the ident, size, and the inner byte array to the output byte array.
    output.push(ident)
    output.append(_Util.make_bytes(size))
    output.append(inner)
    
    output
  
  fun read(command: _Command, buffer: _Buffer): (Bool, String) ? =>
    var offset: U64 = 0
    
    // Peek ident byte to determine number of size bytes, then peek size.
    let ident = buffer.peek_u8(); offset = offset + 1
    let size = match ident
               | 0x04 => offset = offset + 1; U64.from[U8](buffer.peek_u8(1))
               | 0x06 => offset = offset + 8; buffer.peek_u64_be(1)
               else
                 return (false, "unknown command ident byte: " + ident.string(IntHex))
               end
    
    // Raise error if not all bytes are available yet.
    if buffer.size() < (offset + size) then error end
    
    // Skip the bytes obtained by peeking.
    buffer.skip(consume offset)
    
    // Read the name size and name string.
    let name_size = U64.from[U8](buffer.u8())
    let name: String trn = recover String end
    name.append(buffer.block(name_size))
    
    // Read the rest of the body.
    let body: Array[U8] val = buffer.block(size - 1 - name_size)
    
    // Compare to the given command's name
    if name != command.name() then return (false, consume name) end
    
    // Apply the body to the given command's name and return success
    command.read_bytes(body)
    (true, consume name)