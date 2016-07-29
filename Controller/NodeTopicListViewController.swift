//
//  NodeTopicListViewController.swift
//  V2ex-Swift
//
//  Created by huangfeng on 2/3/16.
//  Copyright © 2016 Fin. All rights reserved.
//

import UIKit

class NodeTopicListViewController: BaseViewController ,UITableViewDataSource,UITableViewDelegate  {
    var node:NodeModel?
    var nodeId:String?
    var favorited:Bool = false
    var favoriteUrl:String? {
        didSet{
            let startIndex = favoriteUrl?.rangeOfString("/", options: .BackwardsSearch, range: nil, locale: nil)
            let endIndex = favoriteUrl?.rangeOfString("?")
            nodeId = favoriteUrl?.substringWithRange(Range<String.Index>( startIndex!.endIndex ..< endIndex!.startIndex ))
            if let _ = nodeId , let favoriteUrl = favoriteUrl {
                if favoriteUrl.hasPrefix("/favorite"){
                    favorited = false
                }
                else{
                    favorited = true
                }
                self.setupFavorite()
            }
        }
    }
    var followButton:UIButton?
    private var topicList:Array<TopicListModel>?
    var currentPage = 1
    
    private var _tableView :UITableView!
    private var tableView: UITableView {
        get{
            if(_tableView != nil){
                return _tableView!;
            }
            _tableView = UITableView();
            _tableView.backgroundColor = V2EXColor.colors.v2_backgroundColor
            _tableView.separatorStyle = UITableViewCellSeparatorStyle.None;
            
            regClass(_tableView, cell: HomeTopicListTableViewCell.self)
            
            _tableView.delegate = self
            _tableView.dataSource = self
            return _tableView!;
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if self.node?.nodeId == nil {
            return;
        }

        self.title = self.node?.nodeName
        self.view.backgroundColor = V2EXColor.colors.v2_backgroundColor
        self.view.addSubview(self.tableView);
        self.tableView.snp_makeConstraints{ (make) -> Void in
            make.top.right.bottom.left.equalTo(self.view);
        }
        
        self.showLoadingView()
        
        self.tableView.mj_header = V2RefreshHeader(refreshingBlock: {[weak self] () -> Void in
            self?.refresh()
            })
        self.tableView.mj_header.beginRefreshing()
        
        let footer = V2RefreshFooter(refreshingBlock: {[weak self] () -> Void in
            self?.getNextPage()
            })
        footer.centerOffset = -4
        self.tableView.mj_footer = footer
        
    }
    func refresh(){

        self.currentPage = 1
        
        //如果有上拉加载更多 正在执行，则取消它
        if self.tableView.mj_footer.isRefreshing() {
            self.tableView.mj_footer.endRefreshing()
        }
        
        //根据 tab name 获取帖子列表
        TopicListModel.getTopicList(self.node!.nodeId!, page: self.currentPage){
            [weak self](response:V2ValueResponse<([TopicListModel],String?)>) -> Void in
            if response.success {
                if let weakSelf = self {
                    weakSelf.topicList = response.value?.0
                    weakSelf.favoriteUrl = response.value?.1
                    weakSelf.tableView.reloadData()
                }
            }
            self?.tableView.mj_header.endRefreshing()
            
            self?.hideLoadingView()
        }
    }
    
    func getNextPage(){
        
        if self.topicList == nil || self.topicList?.count <= 0{
            self.tableView.mj_footer.endRefreshing()
            return;
        }
        
        self.currentPage += 1

        TopicListModel.getTopicList(self.node!.nodeId!, page: self.currentPage){
            [weak self](response:V2ValueResponse<([TopicListModel],String?)>) -> Void in
            if response.success {
                if let weakSelf = self , value = response.value  {
                    weakSelf.topicList! += value.0
                    weakSelf.tableView.reloadData()
                }
                else{
                    self?.currentPage -= 1
                }
            }
            self?.tableView.mj_footer.endRefreshing()
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let list = self.topicList {
            return list.count;
        }
        return 0;
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let item = self.topicList![indexPath.row]
        let titleHeight = item.topicTitleLayout?.textBoundingRect.size.height ?? 0
        //          上间隔   头像高度  头像下间隔       标题高度    标题下间隔 cell间隔
        let height = 12    +  35     +  12      + titleHeight   + 12      + 8
        return height
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = getCell(tableView, cell: HomeTopicListTableViewCell.self, indexPath: indexPath);
        cell.bindNodeModel(self.topicList![indexPath.row]);
        return cell;
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let item = self.topicList![indexPath.row]
        
        if let id = item.topicId {
            let topicDetailController = TopicDetailViewController();
            topicDetailController.topicId = id ;
            self.navigationController?.pushViewController(topicDetailController, animated: true)
            tableView .deselectRowAtIndexPath(indexPath, animated: true);
        }
    }

}

extension NodeTopicListViewController {
    func setupFavorite(){
        if(self.followButton != nil){
            return;
        }
        let followButton = UIButton(frame:CGRectMake(0, 0, 26, 26))
        followButton.addTarget(self, action: #selector(toggleFavoriteState), forControlEvents: .TouchUpInside)
        
        let followItem = UIBarButtonItem(customView: followButton)
        
        //处理间距
        let fixedSpaceItem = UIBarButtonItem(barButtonSystemItem: .FixedSpace, target: nil, action: nil)
        fixedSpaceItem.width = -5
        self.navigationItem.rightBarButtonItems = [fixedSpaceItem,followItem]
        
        self.followButton = followButton;
        refreshButtonImage()
    }
    
    func refreshButtonImage() {
        let followImage = self.favorited == true ? UIImage(named: "ic_favorite")! : UIImage(named: "ic_favorite_border")!
        self.followButton?.setImage(followImage.imageWithRenderingMode(.AlwaysTemplate), forState: .Normal)
    }
    
    func toggleFavoriteState(){
        if(self.favorited == true){
            unFavorite()
        }
        else{
            favorite()
        }
        refreshButtonImage()
    }
    func favorite() {
        TopicListModel.favorite(self.nodeId!, type: 0)
        self.favorited = true
        V2Success("收藏成功")
    }
    func unFavorite() {
        TopicListModel.favorite(self.nodeId!, type: 1)
        self.favorited = false
        V2Success("取消收藏了~")
    }
}
