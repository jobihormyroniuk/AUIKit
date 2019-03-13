//
//  AUIUpdatableWideCollectionViewLayout.swift
//  Copyright © 2019 BRANDER. All rights reserved.
//

import UIKit

public protocol AUIUpdatableCollectionViewLayoutDelegate: class {
  func getCellControllers() -> [AUICollectionViewCellController]
  func getIndexPath(for cellController: AUICollectionViewCellController) -> IndexPath?
  func getCellController(for indexPath: IndexPath) -> AUICollectionViewCellController?
}

public protocol AUIUpdatableCollectionViewLayout: class {
  var delegate: AUIUpdatableCollectionViewLayoutDelegate? { get set }
  func prepareForInsert(at indexPaths: [IndexPath])
  func prepareForDelete(at indexPaths: [IndexPath])
  func prepareForUpdate(at indexPaths: [IndexPath])
  func recalculateCellsSizes()
}

open class AUIUpdatableWideCollectionViewLayout: UICollectionViewLayout, AUIUpdatableCollectionViewLayout {
  
  // MARK: - Delegate
  
  weak public var delegate: AUIUpdatableCollectionViewLayoutDelegate?
  
  // MARK: - Private variables
  
  var contentViewHeight: CGFloat = 0
  
  var itemsLayoutAttributes: [UICollectionViewLayoutAttributes] = []
  
  private let mockCollectionView: UICollectionView
  
  override public init() {
    let layout = UICollectionViewFlowLayout()
    layout.itemSize = CGSize(width: 100, height: 100)
    mockCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    super.init()
    mockCollectionView.dataSource = self
    mockCollectionView.delegate = self
  }

  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Prepare
  
  override open func prepare() {
    super.prepare()
    
    guard let delegate = delegate else { return }
    let cellControllers = delegate.getCellControllers()
    
    for cellController in cellControllers {
      guard let indexPath = delegate.getIndexPath(for: cellController) else { continue }
      
      if findLayoutAttributes(for: indexPath) == nil {
        let layoutAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        let cellSize = getCellSize(for: cellController)
        layoutAttributes.frame = CGRect(x: 0, y: contentViewHeight, width: cellSize.width, height: cellSize.height)
        itemsLayoutAttributes.append(layoutAttributes)
        contentViewHeight += cellSize.height
      }
    }
  }
  
  func getCellSize(for cellController: AUICollectionViewCellController) -> CGSize {
    let indexPath = IndexPath(row: 0, section: 0)
    let cell = cellController.cellForRowAtIndexPath(indexPath, collectionView: mockCollectionView)
    let cellSize = cell.sizeThatFits(CGSize(width: collectionViewContentSize.width, height: CGFloat.greatestFiniteMagnitude))
    return CGSize(width: collectionViewContentSize.width, height: cellSize.height)
  }
  
  override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    return itemsLayoutAttributes.filter({ return rect.intersects($0.frame) })
  }
  
  override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return itemsLayoutAttributes.first { $0.indexPath == indexPath }
  }
  
  override open var collectionViewContentSize: CGSize {
    return CGSize(width: UIScreen.main.bounds.width, height: contentViewHeight)
  }
  
  open func register(_ cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {
    mockCollectionView.register(cellClass, forCellWithReuseIdentifier: identifier)
  }
  
  override open func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    guard let collectionView = collectionView else { return true }
    if collectionView.bounds.size != newBounds.size {
      recalculateCellsSizes()
      return true
    } else {
      return false
    }
  }
  
  // MARK: - Prepare for insert
  
  open func prepareForInsert(at indexPaths: [IndexPath]) {
    let sortedIndexPaths = indexPaths.sorted()
    sortedIndexPaths.forEach { insertLayoutAttributes(for: $0) }
  }
  
  func insertLayoutAttributes(for indexPath: IndexPath) {
    guard let cellController = delegate?.getCellController(for: indexPath) else { return }
    let cellSize = getCellSize(for: cellController)
    let layoutAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
    
    let attributesToChange = itemsLayoutAttributes.filter { $0.indexPath >= indexPath }
    attributesToChange.forEach {
      $0.indexPath.row += 1
      $0.frame.origin.y += cellSize.height
    }
    
    contentViewHeight += cellSize.height
    let heightAbove = getHeightBefore(indexPath: indexPath)
    layoutAttributes.frame = CGRect(x: 0, y: heightAbove, width: cellSize.width, height: cellSize.height)
    itemsLayoutAttributes.append(layoutAttributes)
  }
  
  private func getHeightBefore(indexPath: IndexPath) -> CGFloat {
    let attributesAbove = itemsLayoutAttributes.filter { $0.indexPath < indexPath }
    let heightAbove = attributesAbove.reduce(into: 0, { (result, attribute) in
      result += attribute.frame.height
    })
    return heightAbove
  }
  
  // MARK: - Prepare for delete
  
  open func prepareForDelete(at indexPaths: [IndexPath]) {
    let sortedIndexPaths = indexPaths.sorted(by: > )
    sortedIndexPaths.forEach { deleteLayoutAttribute(for: $0) }
  }
  
  func deleteLayoutAttribute(for indexPath: IndexPath) {
    let foundLayoutAttribute = itemsLayoutAttributes.first { $0.indexPath == indexPath }
    guard let layoutAttribute = foundLayoutAttribute else { return }
    let attributesToChange = itemsLayoutAttributes.filter { $0.indexPath > indexPath }
    
    if let index = itemsLayoutAttributes.firstIndex(of: layoutAttribute) {
      itemsLayoutAttributes.remove(at: index)
    }
    attributesToChange.forEach {
      $0.frame.origin.y -= layoutAttribute.frame.height
      $0.indexPath.row -= 1
    }
    contentViewHeight -= layoutAttribute.frame.height
  }
  
  // MARK: - Prepare for update
  
  open func prepareForUpdate(at indexPaths: [IndexPath]) {
    indexPaths.forEach { updateLayoutAttribute(for: $0) }
  }

  private func updateLayoutAttribute(for indexPath: IndexPath) {
    deleteLayoutAttribute(for: indexPath)
    insertLayoutAttributes(for: indexPath)
  }
  
  // MARK: - Find layout attributes
  
  func findLayoutAttributes(for indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return itemsLayoutAttributes.first { $0.indexPath == indexPath }
  }
  
  open func recalculateCellsSizes() {
    guard let delegate = delegate else { return }
    contentViewHeight = 0
    let sortedLayoutAttributes = itemsLayoutAttributes.sorted { $0.indexPath < $1.indexPath }
    sortedLayoutAttributes.forEach {
      if let cellController = delegate.getCellController(for: $0.indexPath) {
        let cellSize = getCellSize(for: cellController)
        if let collectionView = collectionView {
          _ = cellController.cellForRowAtIndexPath($0.indexPath, collectionView: collectionView)
        }
        $0.frame = CGRect(x: 0, y: contentViewHeight, width: cellSize.width, height: cellSize.height)
        contentViewHeight += cellSize.height
      }
    }
  }
  
}

extension AUIUpdatableWideCollectionViewLayout: UICollectionViewDataSource {
  
  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return 1
  }
  
  public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    return UICollectionViewCell()
  }
}

extension AUIUpdatableWideCollectionViewLayout: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
  
  public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return CGSize(width: 100, height: 100)
  }
  
}
