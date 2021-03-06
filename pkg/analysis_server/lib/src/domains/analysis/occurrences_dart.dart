// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library domains.analysis.occurrences_dart;

import 'package:analysis_server/analysis/occurrences_core.dart';
import 'package:analysis_server/src/protocol_server.dart' as protocol;
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';

/**
 * A computer for occurrences in a Dart [CompilationUnit].
 */
class DartOccurrencesComputer implements OccurrencesContributor {
  @override
  void computeOccurrences(
      OccurrencesCollector collector, AnalysisContext context, Source source) {
    List<Source> libraries = context.getLibrariesContaining(source);
    if (libraries.isNotEmpty) {
      CompilationUnit unit =
          context.getResolvedCompilationUnit2(source, libraries.first);
      if (unit != null) {
        _DartUnitOccurrencesComputerVisitor visitor =
            new _DartUnitOccurrencesComputerVisitor();
        unit.accept(visitor);
        visitor.elementsOffsets.forEach((engineElement, offsets) {
          int length = engineElement.displayName.length;
          protocol.Element serverElement =
              protocol.newElement_fromEngine(engineElement);
          protocol.Occurrences occurrences =
              new protocol.Occurrences(serverElement, offsets, length);
          collector.addOccurrences(occurrences);
        });
      }
    }
  }
}

class _DartUnitOccurrencesComputerVisitor extends RecursiveAstVisitor {
  final Map<Element, List<int>> elementsOffsets = <Element, List<int>>{};

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    Element element = node.bestElement;
    if (element != null) {
      _addOccurrence(element, node.offset);
    }
    return super.visitSimpleIdentifier(node);
  }

  void _addOccurrence(Element element, int offset) {
    element = _canonicalizeElement(element);
    if (element == null || element == DynamicElementImpl.instance) {
      return;
    }
    List<int> offsets = elementsOffsets[element];
    if (offsets == null) {
      offsets = <int>[];
      elementsOffsets[element] = offsets;
    }
    offsets.add(offset);
  }

  Element _canonicalizeElement(Element element) {
    if (element is FieldFormalParameterElement) {
      element = (element as FieldFormalParameterElement).field;
    }
    if (element is PropertyAccessorElement) {
      element = (element as PropertyAccessorElement).variable;
    }
    if (element is Member) {
      element = (element as Member).baseElement;
    }
    return element;
  }
}
