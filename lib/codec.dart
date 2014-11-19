library connector.codec;

import 'dart:convert';


typedef T convertFn<S, T>(S val);

class CodecAdapter<S, T> extends Codec<S, T> {
  final convertFn<S, T> encodeFn;
  final convertFn<T, S> decodeFn;

  CodecAdapter(this.encodeFn, this.decodeFn);

  Converter<S, T> get encoder => new ConverterAdapter<S, T>(encodeFn);
  Converter<T, S> get decoder => new ConverterAdapter<T, S>(decodeFn);
}

class ConverterAdapter<S, T> extends Converter<S, T> {
  final convertFn<S, T> converter;

  ConverterAdapter(this.converter);

  T convert(S data) => converter(data);
}

class _ConversionSinkAdapter<S, T> extends ChunkedConversionSink<S> {
  final Converter<S, T> converter;
  final Sink<T> sink;

  _ConversionSinkAdapter(this.converter, this.sink);

  void add(S data) => sink.add(converter.convert(data));
  void close() => sink.close();
}