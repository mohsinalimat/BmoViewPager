//
//  BmoViewPager.swift
//  Pods
//
//  Created by LEE ZHE YU on 2017/4/1.
//
//

import UIKit

@objc public protocol BmoViewPagerDataSource {
    func bmoViewPagerDataSourceNumberOfPage(in viewPager: BmoViewPager) -> Int
    func bmoViewPagerDataSource(_ viewPager: BmoViewPager, viewControllerForPageAt page: Int) -> UIViewController
    
    @objc optional func bmoViewPagerDataSourceTitle(_ viewPager: BmoViewPager, forPageListAt page: Int) -> String?
    @objc optional func bmoViewPagerDataSourceAttributedTitle(_ viewPager: BmoViewPager, forPageListAt page: Int) -> [String : Any]?
    @objc optional func bmoViewPagerDataSourceHighlightedAttributedTitle(_ viewPager: BmoViewPager,
                                                                         forPageListAt page: Int) -> [String : Any]?
    @objc optional func bmoViewPagerDataSourceListItemSize(_ viewPager: BmoViewPager, forPageListAt page: Int) -> CGSize
    @objc optional func bmoViewPagerDataSourceListItemBackgroundView(_ viewPager: BmoViewPager, forPageListAt page: Int) -> UIView?
    @objc optional func bmoViewPagerDataSourceListItemHighlightedBackgroundView(_ viewPager: BmoViewPager,
                                                                                forPageListAt page: Int) -> UIView?
}
@objc public protocol BmoViewPagerDelegate {
    @objc optional func bmoViewPagerDelegate(_ viewPager: BmoViewPager, pageChanged page: Int)
    @objc optional func bmoViewPagerDelegate(_ viewPager: BmoViewPager, shouldSelect page: Int) -> Bool
    @objc optional func bmoViewPagerDelegate(_ viewPager: BmoViewPager, scrollProgress fraction: CGFloat, index: Int)
    @objc optional func bmoViewPagerDelegate(_ viewPager: BmoViewPager, didAppear viewController: UIViewController, page: Int)
}

@IBDesignable
public class BmoViewPager: UIView, BmoPageItemListDelegate, UIScrollViewDelegate {
    @IBInspectable var isHorizontal: Bool = true
    
    /// vierPager scroll orientataion
    public var orientation: UIPageViewControllerNavigationOrientation {
        get {
            if isHorizontal {
                return UIPageViewControllerNavigationOrientation.horizontal
            } else {
                return UIPageViewControllerNavigationOrientation.vertical
            }
        }
    }
    
    /**
     if you need get parent view controller from viewPager's view controller, pass into the bmoViewPager's owner
     if the parent view controller as same as the datasource, it will autoset to bmoViewPager's parent view controller
     */
    public weak var parentViewController: UIViewController? {
        didSet {
            if let vc = parentViewController {
                vc.addChildViewController(pageViewController)
                pageViewController.didMove(toParentViewController: vc)
            }
        }
    }
    
    /// default is nil, if you want pageListBar in custom position, just input the container view
    public weak var pageListContainerView: UIView? = nil
    
    /// enable auto focus, will find the nearest center position for next item
    public var pageListAutoFocus: Bool = true {
        didSet {
            pageListView.autoFocus = pageListAutoFocus
        }
    }
    
    /// enable infinit scroll setting, the page which next the last page will return the first page. 
    public var infinitScroll: Bool = false {
        didSet {
            pageViewController.infinitScroll = infinitScroll
        }
    }
    
    public var pageControlIndex: Int = 0 {
        didSet {
            if oldValue != pageControlIndex {
                self.delegate?.bmoViewPagerDelegate?(self, pageChanged: pageControlIndex)
            }
        }
    }
    public var presentedPageIndex: Int = 0 {
        didSet {
            if oldValue != presentedPageIndex {
                self.pageControlIndex = presentedPageIndex
                self.pageListView.collectionView?.reloadData()
                
                var reuseIt = false
                if let view = pageViewController.pageScrollView?.subviews[safe: 1] {
                    if let vc = view.subviews.first?.bmoVP.ownerVC(), view.subviews.first?.bmoVP.index() == presentedPageIndex {
                        self.delegate?.bmoViewPagerDelegate?(self, didAppear: vc, page: presentedPageIndex)
                        reuseIt = true
                    }
                }
                if reuseIt == false {
                    pageViewController.setViewPagerPage(presentedPageIndex)
                }
            }
        }
    }
    public weak var dataSource: BmoViewPagerDataSource? {
        didSet {
            self.parentViewController = (dataSource as? UIViewController)
            pageViewController.bmoDataSource = dataSource
            pageListView.bmoDataSource = dataSource
            self.addPageListIfNeed()
        }
    }
    public weak var delegate: BmoViewPagerDelegate?
    fileprivate var inited = false
    lazy fileprivate var pageListView: BmoPageItemList = {
        let listView = BmoPageItemList(viewPager: self, delegate: self)
        listView.backgroundColor = UIColor.clear
        return listView
    }()
    lazy fileprivate var pageViewController: BmoPageViewController = {
        let pageVC = BmoPageViewController(viewPager: self, scrollDelegate: self, orientation: self.orientation)
        self.addSubview(pageVC.view)
        pageVC.view.bmoVP.autoFit(self)
        return pageVC
    }()
    fileprivate var lastContentOffSet: CGPoint? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    convenience init(initPage: Int, orientation: UIPageViewControllerNavigationOrientation = .horizontal) {
        self.init()
        self.presentedPageIndex = initPage
        self.isHorizontal = (orientation == .horizontal)
    }
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if inited == false {
            inited = true
            pageListView.reloadData()
            pageViewController.reloadData()
        }
    }
    /// if the viewpager position changed by navigation bar, need to reset contentInset to solve cell wrong position issue
    public func navigationLayoutChanged() {
        self.pageListView.collectionView?.contentInset = .zero
    }
    fileprivate func addPageListIfNeed() {
        if dataSource?.bmoViewPagerDataSourceTitle != nil {
            if let containerView = pageListContainerView {
                if !containerView.subviews.contains(pageListView) {
                    containerView.addSubview(pageListView)
                    pageListView.bmoVP.autoFit(containerView)
                }
            } else {
                if !self.subviews.contains(pageListView) {
                    self.addSubview(pageListView)
                    pageListView.bmoVP.autoFitTop(self, height: 44)
                    let pageTopContraints
                        = self.constraints.filter({$0.firstItem as! NSObject == pageViewController.view && $0.firstAttribute == .top})
                    self.removeConstraints(pageTopContraints)
                    self.addConstraint(NSLayoutConstraint(item: pageViewController.view, attribute: .top, relatedBy: .equal,
                                                          toItem: pageListView, attribute: .bottom, multiplier: 1.0, constant: 0))
                }
            }
        }
    }
    // MARK: - Public
    public func reloadData() {
        pageListView.reloadData()
        pageViewController.reloadData()
    }
    
    // MARK: - BmoPageItemListDelegate
    func bmoViewPageItemList(_ itemList: BmoPageItemList, didSelectItemAt index: Int) {
        if delegate?.bmoViewPagerDelegate?(self, shouldSelect: index) == false {
            return
        }
        var reuseIt = false
        pageViewController.pageScrollView?.subviews.forEach({ (view) in
            if view.subviews.first?.bmoVP.index() == index {
                reuseIt = true
                pageViewController.pageScrollView?.setContentOffset(view.frame.origin, animated: true)
            }
        })
        if reuseIt == false {
            presentedPageIndex = index
        }
    }
    
    // MARK: - UIScrollViewDelegate
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let offSet = lastContentOffSet {
            if self.orientation == .horizontal {
                if abs(offSet.x - scrollView.contentOffset.x) == scrollView.bounds.width {
                    self.presentedPageIndex = self.pageControlIndex
                }
            } else {
                if abs(offSet.y - scrollView.contentOffset.y) == scrollView.bounds.height {
                    self.presentedPageIndex = self.pageControlIndex
                }
            }
        }
        lastContentOffSet = scrollView.contentOffset
        if scrollView.contentOffset.x == scrollView.bounds.width {
            return
        }
        if scrollView.contentOffset.y == scrollView.bounds.height {
            return
        }
        var progressFraction: CGFloat = 0.0
        if self.orientation == .horizontal {
            let originX = scrollView.contentOffset.x
            progressFraction = (originX - scrollView.bounds.width) / scrollView.bounds.width
        } else {
            let originY = scrollView.contentOffset.y
            progressFraction = (originY - pageViewController.view.bounds.height) / pageViewController.view.bounds.height
        }
        var targetIndex = 0
        if progressFraction > 0.0 {
            targetIndex = (progressFraction > 0.5 ? 2 : 1)
        }
        if progressFraction < 0.0 {
            targetIndex = (progressFraction < -0.5 ? 0 : 1)
        }
        if let index = scrollView.subviews[safe: targetIndex]?.subviews.first?.bmoVP.index() {
            if pageControlIndex != index {
                pageControlIndex = index
            }
        }
        delegate?.bmoViewPagerDelegate?(self, scrollProgress: progressFraction, index: pageControlIndex)
        pageListView.updateFocusProgress(&progressFraction)
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        if self.dataSource != nil { return }
        let str1 = "BMO ViewPager"
        let str2 = "Need to implement"
        let str3 = "BmoViewPagerDataSource"
        let str4 = "And assign to the BmoViewPager"
        let mainAttributed = [
            NSForegroundColorAttributeName  : UIColor.black,
            NSFontAttributeName             : UIFont.boldSystemFont(ofSize: 24.0),
        ]
        let subAttributed = [
            NSForegroundColorAttributeName  : UIColor.lightGray,
            NSFontAttributeName             : UIFont.boldSystemFont(ofSize: 17.0),
            ]
        let str1Size = str1.bmoVP.size(attribute: mainAttributed, size: .zero)
        let str2Size = str2.bmoVP.size(attribute: subAttributed, size: .zero)
        let str3Size = str3.bmoVP.size(attribute: subAttributed, size: .zero)
        let str4Size = str4.bmoVP.size(attribute: subAttributed, size: .zero)
        let totalHeight = str1Size.height + str2Size.height + str3Size.height + str4Size.height + 8 * 3
        let str1Point = CGPoint(x: rect.midX - str1Size.width / 2, y: rect.midY - totalHeight / 2)
        let str2Point = CGPoint(x: rect.midX - str2Size.width / 2, y: str1Point.y + str1Size.height + 8)
        let str3Point = CGPoint(x: rect.midX - str3Size.width / 2, y: str2Point.y + str2Size.height + 8)
        let str4Point = CGPoint(x: rect.midX - str4Size.width / 2, y: str3Point.y + str3Size.height + 8)
        (str1 as NSString).draw(at: str1Point, withAttributes: mainAttributed)
        (str2 as NSString).draw(at: str2Point, withAttributes: subAttributed)
        (str3 as NSString).draw(at: str3Point, withAttributes: subAttributed)
        (str4 as NSString).draw(at: str4Point, withAttributes: subAttributed)
    }
}
