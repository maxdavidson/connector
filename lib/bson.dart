library connector.bson;

import 'package:bson/bson.dart' as BSON_EXT;
import 'codec.dart';


final _bson = new BSON_EXT.BSON();

final _obj2bson = new CodecAdapter<dynamic, BSON_EXT.BsonBinary>(_bson.serialize, _bson.deserialize);

final _bson2buffer = new CodecAdapter<BSON_EXT.BsonBinary, List<int>>(
        (binary) => binary.byteList,
        (list) => new BSON_EXT.BsonBinary.from(list));

final BSON = _obj2bson.fuse(_bson2buffer);
