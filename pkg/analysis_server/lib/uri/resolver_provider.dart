// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library analysis_server.uri.resolver_provider;

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/generated/source.dart';

/**
 * A function that will return a [UriResolver] that can be used to resolve a
 * specific kind of URI within the analysis context rooted at the given folder.
 * This is currently being used to provide a package URI resolver that will be
 * used by the server (see [ServerStarter.packageResolverProvider]).
 */
typedef UriResolver ResolverProvider(Folder folder);
