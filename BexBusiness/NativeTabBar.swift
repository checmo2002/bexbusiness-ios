import UIKit
import WebKit

// Thanh Tab gốc cho iPhone (và iPad khi cửa sổ hẹp): thay thanh điều hướng dưới của trang web.
// Trang web vẫn giữ nút của nó (ẩn đi); app đọc trạng thái từ các nút đó và bấm hộ khi người dùng chọn.

/// Trạng thái điều hướng đọc từ `.rail` của trang (gửi lên qua tin `{type:'nav'}`)
struct NavState: Equatable {
    struct Place: Equatable { let index: Int; let name: String; let isDept: Bool; let on: Bool; let locked: Bool }
    struct Item: Equatable { let index: Int; let key: String; let name: String }
    var hasRail = false
    var view = ""
    var badge = ""
    var accent: UIColor?
    var places: [Place] = []
    var views: [Item] = []
    var acts: [Item] = []

    init() {}

    init(_ d: [String: Any]) {
        hasRail = d["rail"] as? Bool ?? false
        view = d["view"] as? String ?? ""
        badge = d["badge"] as? String ?? ""
        accent = (d["acc"] as? String).flatMap(UIColor.init(cssHex:))
        places = (d["places"] as? [[String: Any]] ?? []).map {
            Place(index: $0["i"] as? Int ?? -1, name: $0["name"] as? String ?? "", isDept: $0["dept"] as? Bool ?? false,
                  on: $0["on"] as? Bool ?? false, locked: $0["locked"] as? Bool ?? false)
        }
        views = (d["views"] as? [[String: Any]] ?? []).map { Item(index: $0["i"] as? Int ?? -1, key: $0["v"] as? String ?? "", name: $0["name"] as? String ?? "") }
        acts = (d["acts"] as? [[String: Any]] ?? []).map { Item(index: $0["i"] as? Int ?? -1, key: $0["a"] as? String ?? "", name: $0["name"] as? String ?? "") }
    }
}

enum NativeTabs {
    /// 4 mục cố định (view của trang) + "Thêm"
    static let tabs: [(view: String, title: String, symbol: String)] = [
        ("home", "Trang chủ", "house"),
        ("chat", "Chat", "bubble.left.and.bubble.right"),
        ("tasks", "Công việc", "checklist"),
        ("att", "Chấm công", "clock"),
    ]
    static let moreTag = 99

    static func symbol(forView v: String) -> String {
        switch v {
        case "drive": return "folder"
        case "calendar": return "calendar"
        case "contracts": return "briefcase"
        case "dash": return "chart.bar"
        case "admin": return "shield"
        case "plan": return "checkmark.seal"
        case "platform": return "globe"
        case "settings": return "gearshape"
        default: return "square.grid.2x2"
        }
    }

    static var script: String { scriptTemplate.replacingOccurrences(of: "%CSS%", with: css) }

    /// Đọc `.rail` của trang, gửi trạng thái lên app mỗi khi đổi; cho app bấm hộ nút theo số thứ tự.
    private static let scriptTemplate = #"""
    (function () {
      try { if (localStorage.getItem('bex-rail') === null) localStorage.setItem('bex-rail', '1'); } catch (e) {}
      var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.bex;
      if (!h) return;
      var css = document.createElement('style'); css.id = 'bex-native-tabs-css'; css.textContent = '%CSS%';
      (document.head || document.documentElement).appendChild(css);
      var last = '', els = [], timer = null;
      function label(e) { return (e.getAttribute('aria-label') || e.getAttribute('title') || '').trim(); }
      function scan() {
        var r = document.querySelector('.rail'), st = { type: 'nav', rail: !!r };
        els = [];
        if (r) {
          var on = r.querySelector('[data-view].on'); st.view = on ? on.getAttribute('data-view') : '';
          var hb = document.getElementById('homebadge'); st.badge = (hb && !hb.hidden) ? hb.textContent.trim() : '';
          st.acc = getComputedStyle(document.documentElement).getPropertyValue('--acc').trim();
          st.places = []; st.views = []; st.acts = [];
          r.querySelectorAll('#cos [data-company], #cos [data-dept-nav]').forEach(function (e) {
            var dept = e.hasAttribute('data-dept-nav');
            st.places.push({ i: els.push(e) - 1, name: (e.getAttribute('title') || '').split(' · ')[0], dept: dept,
              on: dept ? e.classList.contains('on') : (e.classList.contains('on') && e.classList.contains('sel')),
              locked: e.classList.contains('locked') });
          });
          [].forEach.call(r.children, function (e) {
            if (e.hasAttribute('data-view')) st.views.push({ i: els.push(e) - 1, v: e.getAttribute('data-view'), name: label(e) });
            else if (e.hasAttribute('data-act')) st.acts.push({ i: els.push(e) - 1, a: e.getAttribute('data-act'), name: label(e) });
          });
        }
        var s = JSON.stringify(st);
        if (s !== last) { last = s; h.postMessage(st); }
      }
      new MutationObserver(function () { if (!timer) timer = setTimeout(function () { timer = null; scan(); }, 80); })
        .observe(document.documentElement, { subtree: true, childList: true, attributes: true, attributeFilter: ['class', 'hidden'] });
      scan();
      window.__bexNav = {
        click: function (i) { var e = els[i]; if (e) e.click(); },
        view: function (v) { var e = document.querySelector('.rail [data-view="' + v + '"]') || document.querySelector('[data-view="' + v + '"]'); if (e) e.click(); },
        native: function (on) { document.documentElement.classList.toggle('bex-native-tabs', !!on); }
      };
    })();
    """#

    /// Khi app dùng thanh gốc: ẩn thanh của trang, trang kéo xuống sát đáy (đáy trang = mép trên thanh gốc)
    static let css = "@media (max-width:760px){html.bex-native-tabs .rail{display:none!important}" +
        "html.bex-native-tabs .main,html.bex-native-tabs #main,html.bex-native-tabs .side,html.bex-native-tabs .shell.side-open .m-back{bottom:0!important}" +
        "html.bex-native-tabs #toast,html.bex-native-tabs .callbox,html.bex-native-tabs .dv-ups{bottom:16px!important}}"
}

/// Bảng "Thêm": chọn công ty / phòng ban, các mục còn lại, giao diện, đăng xuất
final class MoreSheetController: UITableViewController {
    private struct Row { let title: String; let subtitle: String?; let symbol: String?; let indent: Int; let checked: Bool; let dim: Bool; let destructive: Bool; let run: () -> Void }
    private var sections: [(title: String?, rows: [Row])] = []
    private let tint: UIColor

    init(state: NavState, tint: UIColor, perform: @escaping (String) -> Void) {
        self.tint = tint
        super.init(style: .insetGrouped)
        title = "Thêm"
        let tabViews = Set(NativeTabs.tabs.map(\.view))

        var places: [Row] = []
        for p in state.places {
            places.append(Row(title: p.name, subtitle: p.isDept ? (p.locked ? "Chỉ thành viên phòng xem được kênh" : nil) : "Toàn công ty",
                              symbol: p.isDept ? nil : "building.2", indent: p.isDept ? 1 : 0, checked: p.on, dim: p.locked, destructive: false,
                              run: { if !p.on { perform("__bexNav.click(\(p.index))") } }))
        }
        if !places.isEmpty { sections.append(("Công ty và phòng ban", places)) }

        var more: [Row] = state.views.filter { !tabViews.contains($0.key) }.map { v in
            Row(title: v.name, subtitle: nil, symbol: NativeTabs.symbol(forView: v.key), indent: 0, checked: state.view == v.key, dim: false, destructive: false,
                run: { perform("__bexNav.click(\(v.index))") })
        }
        more.append(Row(title: "Cài đặt cá nhân", subtitle: nil, symbol: "person.crop.circle", indent: 0, checked: state.view == "settings", dim: false, destructive: false,
                        run: { perform("__bexNav.view('settings')") }))
        sections.append(("Mục khác", more))

        let acts: [Row] = state.acts.map { a in
            let logout = a.key == "logout"
            return Row(title: logout ? "Đăng xuất" : a.key == "theme" ? "Giao diện sáng / tối" : a.name, subtitle: nil,
                       symbol: logout ? "rectangle.portrait.and.arrow.right" : "circle.lefthalf.filled", indent: 0, checked: false, dim: false,
                       destructive: logout, run: { perform("__bexNav.click(\(a.index))") })
        }
        if !acts.isEmpty { sections.append((nil, acts)) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) không dùng") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tintColor = tint
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
    }

    @objc private func close() { dismiss(animated: true) }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let r = sections[indexPath.section].rows[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var c = cell.defaultContentConfiguration()
        c.text = r.title
        c.secondaryText = r.subtitle
        c.secondaryTextProperties.color = .secondaryLabel
        c.textProperties.color = r.destructive ? .systemRed : (r.dim ? .secondaryLabel : .label)
        if let s = r.symbol { c.image = UIImage(systemName: s) }
        c.imageProperties.tintColor = r.destructive ? .systemRed : tint
        cell.contentConfiguration = c
        cell.indentationLevel = r.indent * 2
        cell.accessoryType = r.checked ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let run = sections[indexPath.section].rows[indexPath.row].run
        dismiss(animated: true, completion: run)
    }
}

extension UIColor {
    /// "#5458F2" / "#58f" → màu; dùng để tô thanh Tab theo màu chủ đạo của trang
    convenience init?(cssHex: String) {
        var s = cssHex.trimmingCharacters(in: .whitespaces)
        guard s.hasPrefix("#") else { return nil }
        s.removeFirst()
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - Gắn thanh Tab vào màn hình web

extension WebViewController: UITabBarDelegate {
    func buildTabBar() {
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.isHidden = true
        var items = NativeTabs.tabs.enumerated().map { i, t in
            UITabBarItem(title: t.title, image: UIImage(systemName: t.symbol), tag: i)
        }
        items.append(UITabBarItem(title: "Thêm", image: UIImage(systemName: "ellipsis.circle"), tag: NativeTabs.moreTag))
        tabBar.items = items
        view.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // cao 49 + phần chừa vạch Home (thanh Tab tự tô nền xuống tận đáy)
            tabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -49),
        ])
    }

    /// Dùng thanh gốc khi: đã đăng nhập (trang có .rail), trang đang ở bố cục điện thoại (≤ 760pt), không phải Mac
    var wantsNativeTabs: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return navState.hasRail && view.bounds.width <= 760
        #endif
    }

    /// syncPage: báo lại cho trang (trang vừa tải lại thì mất lớp bex-native-tabs)
    func updateTabBar(syncPage: Bool = false) {
        let on = wantsNativeTabs
        if on != nativeTabsOn || syncPage {
            nativeTabsOn = on
            tabBar.isHidden = !on
            webBottomToView.isActive = !on
            webBottomToTabBar.isActive = on
            web.evaluateJavaScript("window.__bexNav && __bexNav.native(\(on))", completionHandler: nil)
        }
        guard on, let items = tabBar.items else { return }
        if let acc = navState.accent { tabBar.tintColor = acc }
        let v = navState.view == "dm" ? "home" : navState.view
        let idx = NativeTabs.tabs.firstIndex { $0.view == v }
        tabBar.selectedItem = idx.map { items[$0] } ?? (v.isEmpty ? nil : items.last)
        items[0].badgeValue = navState.badge.isEmpty ? nil : navState.badge
        // chỉ hiện mục nào trang có
        for (i, t) in NativeTabs.tabs.enumerated() { items[i].isEnabled = navState.views.contains { $0.key == t.view } }
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if item.tag == NativeTabs.moreTag {
            updateTabBar() // giữ dấu chọn ở mục đang mở; "Thêm" chỉ mở bảng
            presentMore()
            return
        }
        let v = NativeTabs.tabs[item.tag].view
        web.evaluateJavaScript("window.__bexNav && __bexNav.view('\(v)')", completionHandler: nil)
    }

    private func presentMore() {
        guard presentedViewController == nil else { return }
        let more = MoreSheetController(state: navState, tint: navState.accent ?? Theme.accent) { [weak self] js in
            self?.web.evaluateJavaScript("window.__bexNav && " + js, completionHandler: nil)
        }
        let nav = UINavigationController(rootViewController: more)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }
}
