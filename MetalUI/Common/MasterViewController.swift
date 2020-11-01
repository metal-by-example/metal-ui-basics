
import Cocoa

class MasterViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    @IBOutlet var sourceList: NSOutlineView!
    @IBOutlet var rootDemoView: NSView!
    var currentDemoViewController: NSViewController!
    
    private var stepControllerClasses: [DetailViewController.Type] = []
    private var stepControllers: [DetailViewController?] = []
    private var initialControllerIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerStepControllers()
        
        sourceList.dataSource = self
        sourceList.delegate = self
        sourceList.reloadData()
        
        sourceList.selectRowIndexes(IndexSet(integer: initialControllerIndex), byExtendingSelection: false)
        loadDemoView(at: initialControllerIndex)
    }
    
    func registerStepControllers() {
        stepControllerClasses = [
            RectangleViewController.self,
            GradientViewController.self,
            ImageViewController.self,
            TextViewController.self,
            LineViewController.self
        ]
        stepControllers = [DetailViewController?].init(repeating: nil, count: stepControllerClasses.count)
    }
    
    func loadDemoView(at index: Int) {
        // Look up detail view controller for current step, creating if necessary
        if let stepController = stepControllers[index] {
            currentDemoViewController = stepController
        } else {
            let stepController = stepControllerClasses[index].init()
            stepControllers[index] = stepController
            currentDemoViewController = stepController
        }

        // Replace currently displayed controller view (if any) with current controller's view
        currentDemoViewController.view.frame = rootDemoView.bounds
        currentDemoViewController.view.autoresizingMask = [.width, .height]
        if rootDemoView.subviews.count == 0 {
            rootDemoView.addSubview(currentDemoViewController.view)
        } else {
            rootDemoView.replaceSubview(rootDemoView.subviews.first!, with: currentDemoViewController.view)
        }
    }
    
    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return stepControllerClasses.count
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return stepControllerClasses[index].title
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView,
                     objectValueFor tableColumn: NSTableColumn?,
                     byItem item: Any?) -> Any?
    {
        return item
    }
    
    // MARK: NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let view = NSTextField()
        view.isBordered = false
        view.isEditable = false
        view.backgroundColor = NSColor.clear
        view.stringValue = (item as? String) ?? "Untitled"
        return view
    }
    
    func outlineView(_ outlineView: NSOutlineView,
                     selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet
    {
        if let selectedIndex = proposedSelectionIndexes.first {
            loadDemoView(at: selectedIndex)
        }
        return proposedSelectionIndexes
    }
}
