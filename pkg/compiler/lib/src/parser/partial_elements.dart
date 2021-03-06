// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart2js.parser.partial_elements;

import '../compiler.dart' show
    Compiler;
import '../dart_types.dart' show DynamicType;
import '../diagnostics/diagnostic_listener.dart';
import '../diagnostics/invariant.dart' show
    invariant;
import '../diagnostics/messages.dart';
import '../elements/elements.dart' show
    CompilationUnitElement,
    ConstructorElement,
    Element,
    ElementKind,
    GetterElement,
    LibraryElement,
    MetadataAnnotation,
    MethodElement,
    SetterElement,
    STATE_NOT_STARTED,
    STATE_DONE;
import '../elements/modelx.dart' show
    BaseFunctionElementX,
    ClassElementX,
    ConstructorElementX,
    DeclarationSite,
    ElementX,
    FieldElementX,
    GetterElementX,
    MetadataAnnotationX,
    MethodElementX,
    SetterElementX,
    TypedefElementX,
    VariableList;
import '../elements/visitor.dart' show
    ElementVisitor;
import '../tokens/token.dart' show
    BadInputToken,
    BeginGroupToken,
    ErrorToken,
    KeywordToken,
    StringToken,
    Token,
    UnmatchedToken,
    UnterminatedToken;
import '../tokens/token_constants.dart' as Tokens show
    EOF_TOKEN;
import '../tree/tree.dart';

import 'class_element_parser.dart' show
    ClassElementParser;
import 'parser.dart' show
    Parser;
import 'listener.dart' show
    ParserError;
import 'member_listener.dart' show
    MemberListener;
import 'node_listener.dart' show
    NodeListener;

abstract class PartialElement implements DeclarationSite {
  Token beginToken;
  Token endToken;

  bool hasParseError = false;

  bool get isErroneous => hasParseError;

  DeclarationSite get declarationSite => this;
}

abstract class PartialFunctionMixin implements BaseFunctionElementX {
  FunctionExpression cachedNode;
  Modifiers get modifiers;
  Token beginToken;
  Token getOrSet;
  Token endToken;

  /**
   * The position is computed in the constructor using [findMyName]. Computing
   * it on demand fails in case tokens are GC'd.
   */
  Token _position;

  void init(Token beginToken, Token getOrSet, Token endToken) {
    this.beginToken = beginToken;
    this.getOrSet = getOrSet;
    this.endToken = endToken;
    _position = ElementX.findNameToken(
        beginToken,
        modifiers.isFactory || isGenerativeConstructor,
        name, enclosingElement.name);
  }

  bool get hasNode => cachedNode != null;

  FunctionExpression get node {
    assert(invariant(this, cachedNode != null,
        message: "Node has not been computed for $this."));
    return cachedNode;
  }

  FunctionExpression parseNode(DiagnosticListener listener) {
    if (cachedNode != null) return cachedNode;
    parseFunction(Parser p) {
      if (isClassMember && modifiers.isFactory) {
        p.parseFactoryMethod(beginToken);
      } else {
        p.parseFunction(beginToken, getOrSet);
      }
    }
    cachedNode = parse(listener, this, declarationSite, parseFunction);
    return cachedNode;
  }

  Token get position => _position;

  void reusePartialFunctionMixin() {
    cachedNode = null;
  }

  DeclarationSite get declarationSite;
}

abstract class PartialFunctionElement
    implements PartialElement, PartialFunctionMixin {

  factory PartialFunctionElement(
      String name,
      Token beginToken,
      Token getOrSet,
      Token endToken,
      Modifiers modifiers,
      Element enclosingElement,
      {bool hasBody: true}) {
    if (getOrSet == null) {
      return new PartialMethodElement(
          name, beginToken, endToken, modifiers,
          enclosingElement, hasBody: hasBody);
    } else if (identical(getOrSet.stringValue, 'get')) {
      return new PartialGetterElement(
          name, beginToken, getOrSet, endToken, modifiers,
          enclosingElement, hasBody: hasBody);
    } else {
      assert(identical(getOrSet.stringValue, 'set'));
      return new PartialSetterElement(
          name, beginToken, getOrSet, endToken, modifiers,
          enclosingElement, hasBody: hasBody);
    }
  }

  PartialFunctionElement copyWithEnclosing(Element enclosing);
}


class PartialMethodElement extends MethodElementX
    with PartialElement, PartialFunctionMixin
    implements PartialFunctionElement {
  PartialMethodElement(String name,
                       Token beginToken,
                       Token endToken,
                       Modifiers modifiers,
                       Element enclosing,
                       {bool hasBody: true})
      : super(name, ElementKind.FUNCTION, modifiers, enclosing, hasBody) {
    init(beginToken, null, endToken);
  }

  void reuseElement() {
    super.reuseElement();
    reusePartialFunctionMixin();
  }

  PartialMethodElement copyWithEnclosing(Element enclosing) {
    return new PartialMethodElement(
        name, beginToken, endToken, modifiers, enclosing, hasBody: hasBody);
  }
}

class PartialGetterElement extends GetterElementX
    with PartialElement, PartialFunctionMixin
    implements GetterElement, PartialFunctionElement  {
  PartialGetterElement(String name,
                       Token beginToken,
                       Token getToken,
                       Token endToken,
                       Modifiers modifiers,
                       Element enclosing,
                       {bool hasBody: true})
      : super(name, modifiers, enclosing, hasBody) {
    init(beginToken, getToken, endToken);
  }

  @override
  SetterElement get setter => abstractField.setter;

  void reuseElement() {
    super.reuseElement();
    reusePartialFunctionMixin();
  }

  PartialGetterElement copyWithEnclosing(Element enclosing) {
    return new PartialGetterElement(
        name, beginToken, getOrSet, endToken, modifiers, enclosing,
        hasBody: hasBody);
  }
}

class PartialSetterElement extends SetterElementX
    with PartialElement, PartialFunctionMixin
    implements SetterElement, PartialFunctionElement {
  PartialSetterElement(String name,
                       Token beginToken,
                       Token setToken,
                       Token endToken,
                       Modifiers modifiers,
                       Element enclosing,
                       {bool hasBody: true})
      : super(name, modifiers, enclosing, hasBody) {
    init(beginToken, setToken, endToken);
  }

  @override
  GetterElement get getter => abstractField.getter;

  void reuseElement() {
    super.reuseElement();
    reusePartialFunctionMixin();
  }

  PartialSetterElement copyWithEnclosing(Element enclosing) {
    return new PartialSetterElement(
        name, beginToken, getOrSet, endToken, modifiers, enclosing,
        hasBody: hasBody);
  }
}

class PartialConstructorElement extends ConstructorElementX
    with PartialElement, PartialFunctionMixin {
  PartialConstructorElement(String name,
                            Token beginToken,
                            Token endToken,
                            ElementKind kind,
                            Modifiers modifiers,
                            Element enclosing)
      : super(name, kind, modifiers, enclosing) {
    init(beginToken, null, endToken);
  }

  void reuseElement() {
    super.reuseElement();
    reusePartialFunctionMixin();
  }
}

class PartialFieldList extends VariableList with PartialElement {
  PartialFieldList(Token beginToken,
                   Token endToken,
                   Modifiers modifiers,
                   bool hasParseError)
      : super(modifiers) {
    super.beginToken = beginToken;
    super.endToken = endToken;
    super.hasParseError = hasParseError;
  }

  VariableDefinitions parseNode(Element element, DiagnosticListener listener) {
    if (definitions != null) return definitions;
    listener.withCurrentElement(element, () {
      definitions = parse(
          listener, element, declarationSite,
          (Parser parser) => parser.parseMember(beginToken));

      if (!hasParseError &&
          !definitions.modifiers.isVar &&
          !definitions.modifiers.isFinal &&
          !definitions.modifiers.isConst &&
          definitions.type == null &&
          !definitions.isErroneous) {
        listener.reportError(
            definitions,
            MessageKind.GENERIC,
            { 'text': 'A field declaration must start with var, final, '
                      'const, or a type annotation.' });
      }
    });
    return definitions;
  }

  computeType(Element element, Compiler compiler) {
    if (type != null) return type;
    // TODO(johnniwinther): Compute this in the resolver.
    compiler.withCurrentElement(element, () {
      VariableDefinitions node = parseNode(element, compiler);
      if (node.type != null) {
        type = compiler.resolver.resolveTypeAnnotation(element, node.type);
      } else {
        type = const DynamicType();
      }
    });
    assert(type != null);
    return type;
  }
}

class PartialTypedefElement extends TypedefElementX with PartialElement {

  PartialTypedefElement(
      String name,
      Element enclosing,
      Token beginToken,
      Token endToken)
      : super(name, enclosing) {
    this.beginToken = beginToken;
    this.endToken = endToken;
  }

  Token get token => beginToken;

  Node parseNode(DiagnosticListener listener) {
    if (cachedNode != null) return cachedNode;
    cachedNode = parse(
        listener, this, declarationSite,
        (p) => p.parseTopLevelDeclaration(token));
    return cachedNode;
  }

  Token get position => findMyName(token);
}

/// A [MetadataAnnotation] which is constructed on demand.
class PartialMetadataAnnotation extends MetadataAnnotationX
    implements PartialElement {
  Token beginToken; // TODO(ahe): Make this final when issue 22065 is fixed.

  final Token tokenAfterEndToken;

  Expression cachedNode;

  bool hasParseError = false;

  PartialMetadataAnnotation(this.beginToken, this.tokenAfterEndToken);

  bool get isErroneous => hasParseError;

  DeclarationSite get declarationSite => this;

  Token get endToken {
    Token token = beginToken;
    while (token.kind != Tokens.EOF_TOKEN) {
      if (identical(token.next, tokenAfterEndToken)) break;
      token = token.next;
    }
    assert(token != null);
    return token;
  }

  void set endToken(_) {
    throw new UnsupportedError("endToken=");
  }

  Node parseNode(DiagnosticListener listener) {
    if (cachedNode != null) return cachedNode;
    var metadata = parse(listener,
                         annotatedElement,
                         declarationSite,
                         (p) => p.parseMetadata(beginToken));
    if (metadata is Metadata) {
      cachedNode = metadata.expression;
      return cachedNode;
    } else {
      assert (metadata is ErrorNode);
      return metadata;
    }
  }

  bool get hasNode => cachedNode != null;

  Node get node {
    assert(invariant(this, hasNode));
    return cachedNode;
  }
}

class PartialClassElement extends ClassElementX with PartialElement {
  ClassNode cachedNode;

  PartialClassElement(String name,
                      Token beginToken,
                      Token endToken,
                      Element enclosing,
                      int id)
      : super(name, enclosing, id, STATE_NOT_STARTED) {
    this.beginToken = beginToken;
    this.endToken = endToken;
  }

  void set supertypeLoadState(int state) {
    assert(state == STATE_NOT_STARTED || state == supertypeLoadState + 1);
    assert(state <= STATE_DONE);
    super.supertypeLoadState = state;
  }

  void set resolutionState(int state) {
    assert(state == STATE_NOT_STARTED || state == resolutionState + 1);
    assert(state <= STATE_DONE);
    super.resolutionState = state;
  }

  bool get hasNode => cachedNode != null;

  ClassNode get node {
    assert(invariant(this, cachedNode != null,
        message: "Node has not been computed for $this."));
    return cachedNode;
  }

  ClassNode parseNode(Compiler compiler) {
    if (cachedNode != null) return cachedNode;
    compiler.withCurrentElement(this, () {
      compiler.parser.measure(() {
        MemberListener listener = new MemberListener(compiler, this);
        Parser parser = new ClassElementParser(listener);
        try {
          Token token = parser.parseTopLevelDeclaration(beginToken);
          assert(identical(token, endToken.next));
          cachedNode = listener.popNode();
          assert(
              invariant(
                  beginToken, listener.nodes.isEmpty,
                  message: "Non-empty listener stack: ${listener.nodes}"));
        } on ParserError {
          // TODO(ahe): Often, a ParserError is thrown while parsing the class
          // body. This means that the stack actually contains most of the
          // information synthesized below. Consider rewriting the parser so
          // endClassDeclaration is called before parsing the class body.
          Identifier name = new Identifier(findMyName(beginToken));
          NodeList typeParameters = null;
          Node supertype = null;
          NodeList interfaces = listener.makeNodeList(0, null, null, ",");
          Token extendsKeyword = null;
          NodeList body = listener.makeNodeList(0, beginToken, endToken, null);
          cachedNode = new ClassNode(
              Modifiers.EMPTY, name, typeParameters, supertype, interfaces,
              beginToken, extendsKeyword, body, endToken);
          hasParseError = true;
        }
      });
      compiler.patchParser.measure(() {
        if (isPatched) {
          // TODO(lrn): Perhaps extract functionality so it doesn't
          // need compiler.
          compiler.patchParser.parsePatchClassNode(patch);
        }
      });
    });
    return cachedNode;
  }

  Token get position => beginToken;

  // TODO(johnniwinther): Ensure that modifiers are always available.
  Modifiers get modifiers =>
      cachedNode != null ? cachedNode.modifiers : Modifiers.EMPTY;

  accept(ElementVisitor visitor, arg) {
    return visitor.visitClassElement(this, arg);
  }

  PartialClassElement copyWithEnclosing(CompilationUnitElement enclosing) {
    return new PartialClassElement(name, beginToken, endToken, enclosing, id);
  }
}

Node parse(
    DiagnosticListener diagnosticListener,
    ElementX element,
    PartialElement partial,
    doParse(Parser parser)) {
  CompilationUnitElement unit = element.compilationUnit;
  NodeListener listener = new NodeListener(diagnosticListener, unit);
  listener.memberErrors = listener.memberErrors.prepend(false);
  try {
    if (partial.hasParseError) {
      listener.suppressParseErrors = true;
    }
    doParse(new Parser(listener));
  } on ParserError catch (e) {
    partial.hasParseError = true;
    return new ErrorNode(element.position, e.reason);
  }
  Node node = listener.popNode();
  assert(listener.nodes.isEmpty);
  return node;
}
