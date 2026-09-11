@! ============================================================================
@! MAYA SWARM — DEEP SERIALIZATION ENGINE (universe/swarm/serializer.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Serializes/Deserializes Values, Structs, Arrays, Maps, and Swarm Descriptors
@! ============================================================================

import "universe/core/string"
import "universe/swarm/types"

@! ----------------------------------------------------------------------------
@! 1. Internal Fast JSON Tokenizer & Model
@! ----------------------------------------------------------------------------

@struct JsonToken
  tok_type: string
  tok_str: string
  tok_num: i64
@end

@struct JsonEntry
  key: string
  str_val: string
  num_val: i64
  arr_val: array
  is_str: i64
  is_num: i64
  is_arr: i64
  is_obj: i64
@end

@fn ser_is_digit(c) return c >= 48 && c <= 57 @end
@fn ser_is_whitespace(c) return c == 32 || c == 10 || c == 13 || c == 9 @end

@fn ser_parse_int_substr(s, start, end_idx)
  val = 0
  is_neg = 0
  i = start
  @if i < end_idx && str_char_at(s, i) == 45  @! '-'
    is_neg = 1
    i = i + 1
  @end
  @while i < end_idx
    c = str_char_at(s, i)
    @if ser_is_digit(c)
      val = (val * 10) + (c - 48)
    @end
    i = i + 1
  @end
  @if is_neg == 1 return 0 - val @end
  return val
@end

@fn swarm_json_tokenize(s)
  tokens = []
  i = 0
  num_items = s.len()
  @while i < num_items
    c = str_char_at(s, i)
    @if ser_is_whitespace(c)
      i = i + 1
    @elif c == 123  @! '{'
      tokens.push({ tok_type: "LBRACE", tok_str: "{", tok_num: 0 })
      i = i + 1
    @elif c == 125  @! '}'
      tokens.push({ tok_type: "RBRACE", tok_str: "}", tok_num: 0 })
      i = i + 1
    @elif c == 91   @! '['
      tokens.push({ tok_type: "LBRACKET", tok_str: "[", tok_num: 0 })
      i = i + 1
    @elif c == 93   @! ']'
      tokens.push({ tok_type: "RBRACKET", tok_str: "]", tok_num: 0 })
      i = i + 1
    @elif c == 58   @! ':'
      tokens.push({ tok_type: "COLON", tok_str: ":", tok_num: 0 })
      i = i + 1
    @elif c == 44   @! ','
      tokens.push({ tok_type: "COMMA", tok_str: ",", tok_num: 0 })
      i = i + 1
    @elif c == 34   @! '"'
      j = i + 1
      str_val = ""
      @while j < num_items && str_char_at(s, j) != 34
        sc = str_char_at(s, j)
        @if sc == 92 && j + 1 < num_items
          esc = str_char_at(s, j + 1)
          @if esc == 110 str_val = str_val + "\n"
          @elif esc == 116 str_val = str_val + "\t"
          @elif esc == 114 str_val = str_val + "\r"
          @elif esc == 34 str_val = str_val + "\""
          @elif esc == 92 str_val = str_val + "\\"
          @else str_val = str_val + str_from_char_code(esc)
          @end
          j = j + 2
        @else
          str_val = str_val + str_from_char_code(sc)
          j = j + 1
        @end
      @end
      tokens.push({ tok_type: "STRING", tok_str: str_val, tok_num: 0 })
      i = j + 1
    @elif ser_is_digit(c) || c == 45
      j = i
      @if c == 45 j = j + 1 @end
      @while j < num_items && ser_is_digit(str_char_at(s, j))
        j = j + 1
      @end
      num_val = ser_parse_int_substr(s, i, j)
      tokens.push({ tok_type: "NUMBER", tok_str: "", tok_num: num_val })
      i = j
    @elif c == 116 && i + 3 < num_items  @! 'true'
      tokens.push({ tok_type: "BOOL", tok_str: "true", tok_num: 1 })
      i = i + 4
    @elif c == 102 && i + 4 < num_items  @! 'false'
      tokens.push({ tok_type: "BOOL", tok_str: "false", tok_num: 0 })
      i = i + 5
    @elif c == 110 && i + 3 < num_items  @! 'null'
      tokens.push({ tok_type: "NULL", tok_str: "null", tok_num: 0 })
      i = i + 4
    @else
      i = i + 1
    @end
  @end
  return tokens
@end

@fn parse_json_object(tokens)
  entries = []
  i = 0
  num_items = tokens.len()

  @if i < num_items && tokens[i].tok_type == "LBRACE"
    i = i + 1
  @end

  @while i < num_items && tokens[i].tok_type != "RBRACE"
    @if tokens[i].tok_type == "STRING"
      key_name = tokens[i].tok_str
      i = i + 1
      @if i < num_items && tokens[i].tok_type == "COLON"
        i = i + 1
      @end
      @if i < num_items
        vtok = tokens[i]
        @if vtok.tok_type == "STRING"
          entries.push({ key: key_name, str_val: vtok.tok_str, num_val: 0, arr_val: [], is_str: 1, is_num: 0, is_arr: 0, is_obj: 0 })
          i = i + 1
        @elif vtok.tok_type == "NUMBER" || vtok.tok_type == "BOOL"
          entries.push({ key: key_name, str_val: "", num_val: vtok.tok_num, arr_val: [], is_str: 0, is_num: 1, is_arr: 0, is_obj: 0 })
          i = i + 1
        @elif vtok.tok_type == "LBRACKET"
          i = i + 1
          arr = []
          @while i < num_items && tokens[i].tok_type != "RBRACKET"
            @if tokens[i].tok_type == "NUMBER"
              arr.push(tokens[i].tok_num)
              i = i + 1
            @elif tokens[i].tok_type == "STRING"
              arr.push(tokens[i].tok_str)
              i = i + 1
            @elif tokens[i].tok_type == "COMMA"
              i = i + 1
            @else
              i = i + 1
            @end
          @end
          @if i < num_items && tokens[i].tok_type == "RBRACKET"
            i = i + 1
          @end
          entries.push({ key: key_name, str_val: "", num_val: 0, arr_val: arr, is_str: 0, is_num: 0, is_arr: 1, is_obj: 0 })
        @elif vtok.tok_type == "NULL"
          entries.push({ key: key_name, str_val: "", num_val: 0, arr_val: [], is_str: 0, is_num: 0, is_arr: 0, is_obj: 0 })
          i = i + 1
        @else
          i = i + 1
        @end
      @end
    @elif tokens[i].tok_type == "COMMA"
      i = i + 1
    @else
      i = i + 1
    @end
  @end

  return entries
@end

@fn json_get_str(entries, key: string)
  i = 0
  @while i < entries.len()
    e = entries[i]
    @if e.key == key return e.str_val @end
    i = i + 1
  @end
  return ""
@end

@fn json_get_num(entries, key: string)
  i = 0
  @while i < entries.len()
    e = entries[i]
    @if e.key == key return e.num_val @end
    i = i + 1
  @end
  return 0
@end

@fn json_get_arr(entries, key: string)
  i = 0
  @while i < entries.len()
    e = entries[i]
    @if e.key == key return e.arr_val @end
    i = i + 1
  @end
  return []
@end

@! ----------------------------------------------------------------------------
@! 2. PID Serializer & Deserializer
@! ----------------------------------------------------------------------------

@fn serialize_pid(pid)
  return "{\"node_id\":\"" + pid.node_id + "\",\"actor_id\":" + pid.actor_id.to_str() + ",\"is_remote\":" + pid.is_remote.to_str() + "}"
@end

@fn deserialize_pid(s)
  tokens = swarm_json_tokenize(s)
  entries = parse_json_object(tokens)
  node_id = json_get_str(entries, "node_id")
  actor_id = json_get_num(entries, "actor_id")
  is_remote = json_get_num(entries, "is_remote")
  return pid_new(node_id, actor_id, is_remote)
@end

@! ----------------------------------------------------------------------------
@! 3. NodeID Serializer & Deserializer
@! ----------------------------------------------------------------------------

@fn serialize_node_id(node_id)
  return "{\"id\":\"" + node_id.id + "\",\"cluster_name\":\"" + node_id.cluster_name + "\"}"
@end

@fn deserialize_node_id(s)
  tokens = swarm_json_tokenize(s)
  entries = parse_json_object(tokens)
  id = json_get_str(entries, "id")
  cluster = json_get_str(entries, "cluster_name")
  return node_id_new(id, cluster)
@end

@! ----------------------------------------------------------------------------
@! 4. NodeInfo Serializer & Deserializer
@! ----------------------------------------------------------------------------

@fn serialize_node_info(info)
  return "{\"node_id\":\"" + info.node_id + "\",\"host\":\"" + info.host + "\",\"tcp_port\":" + info.tcp_port.to_str() + ",\"udp_port\":" + info.udp_port.to_str() + ",\"load\":" + info.load.to_str() + ",\"last_seen\":" + info.last_seen.to_str() + ",\"status\":\"" + info.status + "\"}"
@end

@fn deserialize_node_info(s)
  tokens = swarm_json_tokenize(s)
  entries = parse_json_object(tokens)
  node_id = json_get_str(entries, "node_id")
  host = json_get_str(entries, "host")
  tcp_port = json_get_num(entries, "tcp_port")
  udp_port = json_get_num(entries, "udp_port")
  load = json_get_num(entries, "load")
  last_seen = json_get_num(entries, "last_seen")
  status = json_get_str(entries, "status")
  @if status == "" status = "ALIVE" @end
  return node_info_new(node_id, host, tcp_port, udp_port, load, last_seen, status)
@end

@! ----------------------------------------------------------------------------
@! 5. TaskDescriptor Serializer & Deserializer
@! ----------------------------------------------------------------------------

@fn serialize_task_descriptor(desc)
  args_str = "["
  i = 0
  @while i < desc.args.len()
    @if i > 0 args_str = args_str + "," @end
    arg_item = desc.args[i]
    args_str = args_str + arg_item.to_str()
    i = i + 1
  @end
  args_str = args_str + "]"
  return "{\"task_id\":" + desc.task_id.to_str() + ",\"func_name\":\"" + desc.func_name + "\",\"args\":" + args_str + ",\"origin_node\":\"" + desc.origin_node + "\",\"origin_future_id\":" + desc.origin_future_id.to_str() + "}"
@end

@fn deserialize_task_descriptor(s)
  tokens = swarm_json_tokenize(s)
  entries = parse_json_object(tokens)
  task_id = json_get_num(entries, "task_id")
  func_name = json_get_str(entries, "func_name")
  args = json_get_arr(entries, "args")
  origin_node = json_get_str(entries, "origin_node")
  origin_future_id = json_get_num(entries, "origin_future_id")
  return task_descriptor_new(task_id, func_name, args, origin_node, origin_future_id)
@end

@! ----------------------------------------------------------------------------
@! 6. ActorMessage Serializer & Deserializer
@! ----------------------------------------------------------------------------

@fn serialize_actor_message(msg)
  s_node = ""
  s_act = 0
  @if msg.sender != 0
    s_node = msg.sender.node_id
    s_act = msg.sender.actor_id
  @end

  t_node = ""
  t_act = 0
  @if msg.target != 0
    t_node = msg.target.node_id
    t_act = msg.target.actor_id
  @end

  p_val = 0
  @if msg.payload != 0
    p_val = msg.payload
  @end

  return "{\"msg_id\":" + msg.msg_id.to_str() + ",\"sender_node\":\"" + s_node + "\",\"sender_actor\":" + s_act.to_str() + ",\"target_node\":\"" + t_node + "\",\"target_actor\":" + t_act.to_str() + ",\"msg_type\":\"" + msg.msg_type + "\",\"payload\":" + p_val.to_str() + "}"
@end

@fn deserialize_actor_message(s)
  tokens = swarm_json_tokenize(s)
  entries = parse_json_object(tokens)
  msg_id = json_get_num(entries, "msg_id")
  s_node = json_get_str(entries, "sender_node")
  s_act = json_get_num(entries, "sender_actor")
  t_node = json_get_str(entries, "target_node")
  t_act = json_get_num(entries, "target_actor")
  msg_type = json_get_str(entries, "msg_type")
  payload = json_get_num(entries, "payload")

  sender = pid_new(s_node, s_act, 0)
  target = pid_new(t_node, t_act, 0)

  return actor_message_new(msg_id, sender, target, msg_type, payload)
@end

@! ----------------------------------------------------------------------------
@! 7. SwarmJoinHandle Serializer & Deserializer
@! ----------------------------------------------------------------------------

@fn serialize_join_handle(join_h: SwarmJoinHandle)
  res_str = ""
  @if join_h.result != 0
    res_str = join_h.result.to_str()
  @else
    res_str = "0"
  @end
  return "{\"task_id\":" + join_h.task_id.to_str() + ",\"is_remote\":" + join_h.is_remote.to_str() + ",\"local_pid\":" + join_h.local_pid.to_str() + ",\"remote_node\":\"" + join_h.remote_node + "\",\"future_id\":" + join_h.future_id.to_str() + ",\"completed\":" + join_h.completed.to_str() + ",\"result\":" + res_str + "}"
@end

@fn deserialize_join_handle(s)
  tokens = swarm_json_tokenize(s)
  entries = parse_json_object(tokens)
  task_id = json_get_num(entries, "task_id")
  is_remote = json_get_num(entries, "is_remote")
  local_pid = json_get_num(entries, "local_pid")
  remote_node = json_get_str(entries, "remote_node")
  future_id = json_get_num(entries, "future_id")
  completed = json_get_num(entries, "completed")
  result = json_get_num(entries, "result")

  h = swarm_join_handle_new(task_id, is_remote, local_pid, remote_node, future_id)
  h.completed = completed
  h.result = result
  return h
@end

@! ----------------------------------------------------------------------------
@! 8. Generic Swarm Value Serializer & Deserializer
@! ----------------------------------------------------------------------------

@fn swarm_serialize_value(val)
  @if val == 0 return "0" @end
  return val.to_str()
@end

@fn swarm_deserialize_value(s)
  tokens = swarm_json_tokenize(s)
  @if tokens.len() == 0 return s @end
  tok = tokens[0]
  @if tok.tok_type == "NUMBER" return tok.tok_num @end
  @if tok.tok_type == "STRING" return tok.tok_str @end
  @if tok.tok_type == "BOOL" return tok.tok_num @end
  return s
@end
