//
//  CodeWriter.swift
//  SwiftPoet
//
//  Created by Kyle Dorman on 11/10/15.
//
//

import Foundation

public typealias Appendable = String.CharacterView

open class CodeWriter: NSObject {
    fileprivate var _out: Appendable
    open var out: String {
        return String(_out)
    }

    fileprivate var indentLevel: Int

    public init(out: Appendable = Appendable(""), indentLevel: Int = 0) {
        self._out = out
        self.indentLevel = indentLevel
    }
}

// MARK: Indentation
public extension CodeWriter
{
    @discardableResult
    public func indent()
        -> CodeWriter
    {
        return indent(1)
    }

    @discardableResult
    public func indent(_ levels: Int)
        -> CodeWriter
    {
        return indentLevels(levels)
    }

    @discardableResult
    public func unindent()
        -> CodeWriter
    {
        return unindent(1)
    }

    @discardableResult
    public func unindent(_ levels: Int)
        -> CodeWriter
    {
        return indentLevels(-levels)
    }

    @discardableResult
    fileprivate func indentLevels(_ levels: Int)
        -> CodeWriter
    {
        indentLevel = max(indentLevel + levels, 0)
        return self
    }
}

extension CodeWriter {
    //
    //  FileName.swift
    //  Framework
    //
    //  Contains:
    //  PoetSpecType PoetSpecName
    //  PoetSpecType2 PoetSpecName2
    //
    //  Created by SwiftPoet on MM/DD/YYYY
    //
    //
    public func emitFileHeader(fileName: String?, framework: String?, specs: [PoetSpecType]) {
        let specStr: [String] = specs.map { spec in
            return headerLine(withString: "\(spec.construct.stringValue) \(spec.name)")
        }

        var header: [String] = [headerLine()]
        if let fileName = fileName {
            header.append(headerLine(withString: "\(fileName).swift"))
        }
        header.append(headerLine())
        if let framework = framework {
            header.append(headerLine(withString: framework))
            header.append(headerLine())
        }

        if !specStr.isEmpty {
            header.append(headerLine(withString: "Contains:"))
            header.append(contentsOf: specStr)
            header.append(headerLine())
        }

        header.append(headerLine(withString: generatedByAt()))
        header.append(headerLine())
        header.append(headerLine())
        
        _out.append(contentsOf: header.joined(separator: "\n").characters)
        emitNewLine()
        emitNewLine()
    }

    fileprivate func headerLine(withString str: String? = nil) -> String {
        guard let str = str else {
            return "//"
        }
        return "//  \(str)"
    }

    fileprivate func createdAt() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: Date())
    }

    fileprivate func generatedByAt() -> String {
        return "Generated by SwiftPoet on \(createdAt())"
    }

    @discardableResult
    public func emit(imports toEmit: Set<String>)
        -> CodeWriter
    {
        if (toEmit.count > 0) {
            let importString = toEmit.joined(separator: "\nimport ")
            _out.append(contentsOf: "import ".characters)
            _out.append(contentsOf: importString.characters)
            _out.append(contentsOf: "\n\n".characters)
        }
        return self
    }

    @discardableResult
    public func emit(documentationFor type: TypeSpec)
        -> CodeWriter
    {
        if let docs = type.description {
            var specDoc = "" as String

            let firstline = "/**\n".byIndenting(level: indentLevel)
            let lastline = "*/\n".byIndenting(level: indentLevel)
            let indentedDocs = "\(docs)\n".byIndenting(level: indentLevel + 1)

            specDoc.append(firstline)
            specDoc.append(indentedDocs)
            specDoc.append(lastline)
            _out.append(contentsOf: specDoc.characters)
        }
        return self
    }

    @discardableResult
    public func emit(documentationFor field: FieldSpec)
        -> CodeWriter
    {
        if let docs = field.description {
            let comment = "// \(docs)\n".byIndenting(level: indentLevel)
            _out.append(contentsOf: comment.characters)
        }
        return self
    }

    @discardableResult
    public func emit(documentationFor method: MethodSpec)
        -> CodeWriter
    {
        guard method.description != nil || method.parameters.count > 0 else {
            return self
        }

        var specDoc = "" as String

        let firstline = "/**\n".byIndenting(level: indentLevel)
        let lastline = "*/\n".byIndenting(level: indentLevel)
        let indentedDocs = PoetUtil.fmap(method.description) {
            "\($0)\n".byIndenting(level: self.indentLevel + 1)
        }

        specDoc.append(firstline)
        if indentedDocs != nil {
            specDoc.append(indentedDocs!)
        }

        var first = true
        method.parameters.forEach { p in
            if first && method.description != nil {
                specDoc.append("\n")
            } else if !first {
                specDoc.append("\n\n")
            }
            first = false

            var paramDoc = ":param:    \(p.name)"
            if let desc = p.description {
                paramDoc.append(" \(desc)")
            }
            specDoc.append(paramDoc.byIndenting(level: indentLevel + 1))
        }
        specDoc.append("\n")
        specDoc.append(lastline)
        _out.append(contentsOf: specDoc.characters)
        return self
    }

    @discardableResult
    public func emit(modifiers toEmit: Set<Modifier>)
        -> CodeWriter
    {
        guard toEmit.count > 0 else {
            _out.append(contentsOf: "".byIndenting(level: indentLevel).characters)
            return self
        }

        let modListStr = Array(toEmit).map { m in
            return m.rawString
        }.joined(separator: " ") + " "

        _out.append(contentsOf: modListStr.byIndenting(level: indentLevel).characters)

        return self
    }

    @discardableResult
    public func emit(codeBlock toEmit: CodeBlock, withIndentation indent: Bool = false)
        -> CodeWriter
    {
        if indent {
            emitIndentation()
        }

        var first = true
        toEmit.emittableObjects.forEach { either in
            switch either {
            case .right(let codeBlock):
                self.emitNewLine()
                self.emit(codeBlock: codeBlock, withIndentation: true)

            case .left(let emitObject):
                switch emitObject.type {
                case .literal:
                    self.emit(literal: emitObject.data, first: first, trimString: emitObject.trimString)

                case .beginStatement:
                    self.emitBeginStatement()

                case .endStatement:
                    self.emitEndStatement()

                case .newLine:
                    self.emitNewLine()

                case .increaseIndentation:
                    self.indent()

                case .decreaseIndentation:
                    self.unindent()

                case .codeLine:
                    self.emitNewLine()
                    self.emit(literal: emitObject.data as! Literal, withIndentation: true)

                case .emitter:
                    self.emit(using: emitObject.data as! Emitter, first: first)
                }
                first = false
            }
        }
        return self
    }

    @discardableResult
    public func emit(type: EmitType, data: Any? = nil) -> CodeWriter {
        let cbBuilder = CodeBlock.builder()
        cbBuilder.add(type: type, data: data)
        return self.emit(codeBlock: cbBuilder.build())
    }

    @discardableResult
    public func emit(literal value: Any?, withIndentation indent: Bool = false)
         -> CodeWriter
    {
        if indent {
            emitIndentation()
        }
        emit(literal: value, first: true)
        return self
    }

    fileprivate func emit(literal value: Any?, first: Bool = false, trimString: Bool = false) {
        if let _ = value as? TypeSpec {
            // Dunno
        } else if let literalType = value as? Literal {
            var lv = literalType.literalValue().characters
            if !first && !trimString { lv.insert(" ", at: lv.startIndex) }
            _out.append(contentsOf: lv)
        } else if let str = value as? String {
            _out.append(contentsOf: str.characters)
        }
    }

    fileprivate func emit(using emitter: Any?, first: Bool = true)
    {
        if let emitter = emitter as? Emitter {
            if !first { _out.append(" ") }
            emitter.emit(to: self)
        }
    }

    @discardableResult
    public func emit(superType: TypeName?, protocols: [TypeName]?)
        -> CodeWriter
    {
        var inheritanceValues: [String?] = [superType?.literalValue()]
        if let protocols = protocols {
            inheritanceValues.append(contentsOf: protocols.map{ $0.literalValue() })
        }

        let stringValues = inheritanceValues.flatMap{$0}

        if stringValues.count > 0 {
            _out.append(contentsOf: ": ".characters)
            _out.append(contentsOf: stringValues.joined(separator: ", ").characters)
        }

        return self
    }

    fileprivate func emitBeginStatement()
    {
        let begin = " {"
        _out.append(contentsOf: begin.characters)
        indent()
    }

    fileprivate func emitEndStatement()
    {
        let newline = "\n"
        unindent()
        let endBracket = "}".byIndenting(level: indentLevel)
        let end = newline + endBracket
        _out.append(contentsOf: end.characters)
    }

    @discardableResult
    public func emitNewLine()
        -> CodeWriter
    {
        _out.append("\n")
        return self
    }

    fileprivate func emitIndentation()
    {
        _out.append(contentsOf: "".byIndenting(level: indentLevel).characters)
    }

    @discardableResult
    public func emit(specs toEmit: [Emitter])
        -> CodeWriter
    {
        _out.append(contentsOf: (toEmit.map { spec in
            spec.toString()
        }).joined(separator: "\n\n").characters)
        emitNewLine()
        return self
    }
}

extension String {
    fileprivate func byIndenting(level indentationLevel: Int)
        -> String
    {
        let indentSpacing = "    "

        var indented = ""
        indentationLevel.times {
            indented += indentSpacing
        }
        return indented + self
    }
}

extension Int {
    fileprivate func times(_ fn: () -> Void) {
        for _ in 0..<self {
            fn()
        }
    }
}

