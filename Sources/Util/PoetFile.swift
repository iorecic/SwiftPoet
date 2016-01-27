//
//  PoetFile.swift
//  SwiftPoet
//
//  Created by Kyle Dorman on 1/25/16.
//
//

import Foundation

// Represents a list of PoetSpecs in a single file
public protocol PoetFileProtocol {
    var fileName: String? { get }
    var specList: [PoetSpec] { get }
    var fileContents: String { get }

    func append(item: PoetSpec)
}


public class PoetFile: PoetFileProtocol, Importable {
    public private(set) var fileName: String?
    public private(set) var specList: [PoetSpec]
    public var fileContents: String {
        return toFile()
    }

    public var imports: Set<String> {
        return collectImports()
    }

    private var framework: String?

    public init(list: [PoetSpec], framework: String? = nil) {
        self.specList = list
        self.fileName = list.first?.name
        self.framework = framework
    }

    public convenience init(spec: PoetSpec, framework: String? = nil) {
        self.init(list: [spec], framework: framework)
    }

    public func append(item: PoetSpec) {
        specList.append(item)
        if fileName == nil {
            fileName = item.name
        }
    }

    public func collectImports() -> Set<String> {
        return specList.reduce(Set<String>()) { set, spec in
            return set.union(spec.collectImports())
        }
    }

    private func toFile() -> String {
        let codeWriter = CodeWriter()
        codeWriter.emitFileHeader(fileName, framework: framework, specs: specList)
        codeWriter.emitImports(imports)
        codeWriter.emitSpecs(specList)
        return codeWriter.out
    }
}
