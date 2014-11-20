library connector.codec;

import 'dart:convert';


typedef T convertFn<S, T>(S val);

/// Creates a [Codec] object using a pair of encode and a decode functions.
class CodecAdapter<S, T> extends Codec<S, T> {
  final convertFn<S, T> encodeFn;
  final convertFn<T, S> decodeFn;

  CodecAdapter(this.encodeFn, this.decodeFn);

  Converter<S, T> get encoder => new _ConverterAdapter<S, T>(encodeFn);
  Converter<T, S> get decoder => new _ConverterAdapter<T, S>(decodeFn);
}

class _ConverterAdapter<S, T> extends Converter<S, T> {
  final convertFn<S, T> converter;

  _ConverterAdapter(this.converter);

  T convert(S data) => converter(data);
}

class _ConversionSinkAdapter<S, T> extends ChunkedConversionSink<S> {
  final Converter<S, T> converter;
  final Sink<T> sink;

  _ConversionSinkAdapter(this.converter, this.sink);

  add(S data) => sink.add(converter.convert(data));
  close() => sink.close();
}
