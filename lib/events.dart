
import 'dart:async';

class EventEmitter {
  /*
   * Mapping of events to a list of event handlers
   */
  Map<String, List<Function>> _events;

  /*
   * Mapping of events to a list of one-time event handlers
   */
  Map<String, List<Function>> _eventsOnce;

  /*
   * Typical constructor
   */
  EventEmitter() {
    this._events = new Map<String, List<Function>>();
    this._eventsOnce = new Map<String, List<Function>>();
  }

  dynamic callback(Function func, [arg0, arg1, arg2, arg3, arg4, arg5]) {
    String arguments = func.runtimeType.toString().split(' => ')[0];
    if (arguments.length > 3) {
      String args = arguments.substring(1, arguments.length - 1);
      int argc = args.split(', ').length;
      switch (argc) {
        case 1:
          return func(arg0 ?? null);
        case 2:
          return func(arg0 ?? null, arg1 ?? null);
        case 3:
          return func(arg0 ?? null, arg1 ?? null, arg2 ?? null);
        case 4:
          return func(arg0 ?? null, arg1 ?? null, arg2 ?? null, arg3 ?? null);
        case 5:
          return func(arg0 ?? null, arg1 ?? null, arg2 ?? null, arg3 ?? null,
              arg4 ?? null);
        case 5:
          return func(arg0 ?? null, arg1 ?? null, arg2 ?? null, arg3 ?? null,
              arg4 ?? null, arg5 ?? null);
      }
    } else {
      return func();
    }
  }

  /*
   * This function triggers all the handlers currently listening
   * to `event` and passes them `data`.
   *
   * @param String event - The event to trigger
   * @param [args] - The variable numbers of arguments to send to each handler
   * @return void
   */
  dynamic emit(String event, [arg0, arg1, arg2, arg3, arg4, arg5]) {
    this._events[event]?.forEach((Function func) {
      return callback(func, arg0, arg1, arg2, arg3, arg4, arg5);
    });
    this._eventsOnce.remove(event)?.forEach((Function func) {
      return callback(func, arg0, arg1, arg2, arg3, arg4, arg5);
    });
    return null;
  }

  /*
   * This function binds the `handler` as a listener to the `event`
   *
   * @param String event     - The event to add the handler to
   * @param Function handler - The handler to bind to the event
   * @return void
   */
  void on(String event, Function handler) {
    this._events.putIfAbsent(event, () => new List<Function>());
    this._events[event].add(handler);
  }

  /*
   * This function binds the `handler` as a listener to the first
   * occurrence of the `event`. When `handler` is called once,
   * it is removed.
   *
   * @param String event     - The event to add the handler to
   * @param Function handler - The handler to bind to the event
   * @return void
   */
  void once(String event, Function handler) {
    this._eventsOnce.putIfAbsent(event, () => new List<Function>());
    this._eventsOnce[event].add(handler);
  }

  /*
   * This function attempts to unbind the `handler` from the `event`
   *
   * @param String event     - The event to remove the handler from
   * @param Function handler - The handler to remove
   * @return void
   */
  void remove(String event, Function handler) {
    this._events[event]?.removeWhere((item) => item == handler);
    this._eventsOnce[event]?.removeWhere((item) => item == handler);
  }

  /*
   * This function attempts to unbind all the `handler` from the `event`
   *
   * @param String event     - The event to remove the handler from
   * @return void
   */
  void off(String event) {
    this._events[event] = new List<Function>();
    this._eventsOnce[event] = new List<Function>();
  }

  /*
   * This function unbinds all the handlers for all the events
   *
   * @return void
   */
  void clearListeners() {
    this._events = new Map<String, List<Function>>();
    this._eventsOnce = new Map<String, List<Function>>();
  }

  bool hasListener(String event) {
    return this._events.containsKey(event) || this._eventsOnce.containsKey(event);
  }
}