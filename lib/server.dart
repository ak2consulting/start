#library('server');

#import('dart:io');
#import('response.dart');
#import('request.dart');

class Server {
  HttpServer _server;
  
  Server() : _server = new HttpServer();
  
  void stop() {
    _server.close();
  }
  
  void listen(host, port) {
    _server.defaultRequestHandler = (HttpRequest req, HttpResponse res) {
      new Response(res).status(404).send('Not found!');
      return;
    };
    _server.listen(host, port);
  }

  void noSuchMethod(String name, List args) {
    if (['get','post','put','delete'].indexOf(name) < 0) {
      throw new Exception('No such HTTP method');
    }
    
    Map route = {
      'method': name.toUpperCase(),
      'path': normalize(args[0]),
      'action': args[1]
    };
    
    _server.addRequestHandler(
      getMatcher(route),
      getHandler(route)
    );
  }
  
  getMatcher(Map route) {
    return (HttpRequest req) {
      String method = req.method;
      String path = req.path;
      return route['method'] == method.toUpperCase()
          && route['path']['regexp'].hasMatch(path);
    };
  }
  
  getHandler(Map route) {
    return (HttpRequest req, HttpResponse res) {
      Request request = new Request(req);
      request.params = parseParams(req.path, route['path']);
      route['action'](request, new Response(res));
    };
  }
  
  Map normalize(path, [bool strict = false]) {
    if (path is RegExp) {
      return path;
    }
    if (path is List) {
      path = '(' + Strings.join(path, '|') + ')';
    }
    path = path.concat(strict ? '' : '/?');

    List keys = [];

    RegExp placeholderRE = const RegExp(@'(\.)?:(\w+)(\?)?');
    Iterable<Match> matches = placeholderRE.allMatches(path);

    for (Match placeholder in matches) {
      String replace = '(?:';
      if (placeholder[1] !== null) {
        replace += '\.';
      }
      replace += '(\\w+))';
      if (placeholder[3] !== null) {
        replace += '?';
      }
      path = path.replaceFirst(placeholder[0], replace);
      keys.add(placeholder[2]);
    }

    path = path.replaceAll('//', '/');

    return {
      'regexp': new RegExp('^' + path + '\$'),
      'keys': keys
    };
  }

  Map parseParams(String path, Map routePath) {
    Map params = {};
    Match paramsMatch = routePath['regexp'].firstMatch(path);
    for (var i = 0; i < routePath['keys'].length; i++) {
      params[routePath['keys'][i]] = paramsMatch[i+1];
    }
    return params;
  }
}
