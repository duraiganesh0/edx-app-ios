//
//  CourseSectionTableViewCell.swift
//  edX
//
//  Created by Ehmad Zubair Chughtai on 04/06/2015.
//  Copyright (c) 2015 edX. All rights reserved.
//

import UIKit

protocol CourseSectionTableViewCellDelegate : class {
    func sectionCellChoseDownload(cell : CourseSectionTableViewCell, videos : [OEXHelperVideoDownload], forBlock block : CourseBlock)
    func sectionCellChoseShowDownloads(cell : CourseSectionTableViewCell)
    func sectionCellUpdate(cell: CourseSectionTableViewCell)
}

class CourseSectionTableViewCell: SwipeCellView, CourseBlockContainerCell {
    
    static let identifier = "CourseSectionTableViewCellIdentifier"
    
    fileprivate let content = CourseOutlineItemView()
    private let downloadView = DownloadsAccessoryView()

    weak var courseSectionDelegate : CourseSectionTableViewCellDelegate?
    
    private let videosStream = BackedStream<[OEXHelperVideoDownload]>()
    

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(content)
        content.snp_makeConstraints { (make) -> Void in
            make.edges.equalTo(contentView)
        }

        downloadView.downloadAction = {[weak self] _ in
            if let owner = self, let block = owner.block, let videos = self?.videosStream.value {
                owner.courseSectionDelegate?.sectionCellChoseDownload(cell: owner, videos: videos, forBlock: block)
            }
        }
        videosStream.listen(self) {[weak self] downloads in
            if let downloads = downloads.value, let state = self?.downloadStateForDownloads(videos: downloads) {
                self?.downloadView.state = state
                self?.content.trailingView = self?.downloadView
                self?.downloadView.itemCount = downloads.count
            }
            else {
                self?.content.trailingView = nil
            }
        }
        
        for notification in [NSNotification.Name.OEXDownloadProgressChanged, NSNotification.Name.OEXDownloadEnded, NSNotification.Name.OEXVideoStateChanged] {
            NotificationCenter.default.oex_addObserver(observer: self, name: notification.rawValue) { (_, observer, _) -> Void in
                if let state = observer.downloadStateForDownloads(videos: observer.videosStream.value) {
                    observer.downloadView.state = state
                }
                else {
                    observer.content.trailingView = nil
                }
            }
        }
        
        let tapGesture = UITapGestureRecognizer()
        tapGesture.addAction {[weak self]_ in
            if let owner = self, owner.downloadView.state == .Downloading {
                owner.courseSectionDelegate?.sectionCellChoseShowDownloads(cell: owner)
            }
        }
        downloadView.addGestureRecognizer(tapGesture)
    }
    
    var videos : OEXStream<[OEXHelperVideoDownload]> = OEXStream() {
        didSet {
            videosStream.backWithStream(videos)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        videosStream.backWithStream(OEXStream(value:[]))
        self.reset()
    }
    
    func downloadStateForDownloads(videos : [OEXHelperVideoDownload]?) -> DownloadsAccessoryView.State? {
        guard let videos = videos, videos.count > 0 else { return nil }
        
        let allCompleted = videos.reduce(true) {(acc, video) in
            return acc && video.downloadState == .complete
        }
        
        if allCompleted {
            return .Done
        }
        
        let filteredVideos = filterVideos(videos: videos)
        
        let allDownloading = filteredVideos.reduce(true) {(acc, video) in
            return acc && video.downloadState == .partial
        }
        
        if allDownloading {
            return .Downloading
        }
        else {
            return .Available
        }
    }
    
    private func filterVideos(videos: [OEXHelperVideoDownload])-> [OEXHelperVideoDownload]{
        var incompleteVideos:[OEXHelperVideoDownload]  = []
        for video in videos {
            // only return incomplete videos
            if video.downloadState != .complete {
                incompleteVideos.append(video)
            }
        }
        
        return incompleteVideos
    }
    
    
    private func deleteVideos(videos : [OEXHelperVideoDownload]) {
        OEXInterface.shared().deleteDownloadedVideos(videos) { (deleted) in
            
        }
    }
    
    public func isAllVideosDownloaded() -> Bool {
        var downloadingState : Bool = false
        videosStream.listen(self) {[weak self] downloads in
            if let downloads = downloads.value, let videoState = self?.downloadStateForDownloads(videos: downloads) {
                downloadingState = (videoState == .Done)
            }
        }
        return downloadingState
    }
    
    public func deleteDownloadedVideos() {
        videosStream.listen(self) {[weak self] downloads in
            if let downloads = downloads.value {
                self?.deleteVideos(videos: downloads)
            }
        }
    }
    
    var block : CourseBlock? = nil {
        didSet {
            content.setTitleText(title: block?.displayName)
            content.isGraded = block?.graded
            content.setDetailText(title: block?.format ?? "")
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CourseSectionTableViewCell: SwipeCellViewDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction]? {
        
        if(!self.isAllVideosDownloaded() || orientation == .left) {
            return nil
        }
    
        let delete = SwipeAction(title: nil) { action, indexPath in
            self.deleteDownloadedVideos()
            self.courseSectionDelegate?.sectionCellUpdate(cell: self)
        }
        
        delete.image = Icon.Trash.imageWithFontSize(size: 30)
        delete.backgroundColor = UIColor.red
        return [delete]
    }
}
