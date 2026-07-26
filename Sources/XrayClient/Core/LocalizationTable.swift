import Foundation

extension Loc {
    /// Translation table: English key → [language code: translation].
    /// Languages: ru, zh, es, hi, ar, fr, pt, de, ja, id, tr.
    static let table: [String: [String: String]] = [

        // MARK: Connection status
        "Connected": [
            "ru": "Подключено", "zh": "已连接", "es": "Conectado", "hi": "कनेक्टेड",
            "ar": "متصل", "fr": "Connecté", "pt": "Conectado", "de": "Verbunden",
            "ja": "接続済み", "id": "Terhubung", "tr": "Bağlandı"],
        "Connecting…": [
            "ru": "Подключение…", "zh": "连接中…", "es": "Conectando…", "hi": "कनेक्ट हो रहा है…",
            "ar": "جارٍ الاتصال…", "fr": "Connexion…", "pt": "Conectando…", "de": "Verbinde…",
            "ja": "接続中…", "id": "Menghubungkan…", "tr": "Bağlanıyor…"],
        "Disconnected": [
            "ru": "Отключено", "zh": "已断开", "es": "Desconectado", "hi": "डिस्कनेक्टेड",
            "ar": "غير متصل", "fr": "Déconnecté", "pt": "Desconectado", "de": "Getrennt",
            "ja": "切断済み", "id": "Terputus", "tr": "Bağlantı kesildi"],

        // MARK: Buttons / actions
        "Connect": [
            "ru": "Подключить", "zh": "连接", "es": "Conectar", "hi": "कनेक्ट",
            "ar": "اتصال", "fr": "Connecter", "pt": "Conectar", "de": "Verbinden",
            "ja": "接続", "id": "Hubungkan", "tr": "Bağlan"],
        "Disconnect": [
            "ru": "Отключить", "zh": "断开", "es": "Desconectar", "hi": "डिस्कनेक्ट",
            "ar": "قطع الاتصال", "fr": "Déconnecter", "pt": "Desconectar", "de": "Trennen",
            "ja": "切断", "id": "Putuskan", "tr": "Bağlantıyı kes"],
        "Select a server": [
            "ru": "Выберите сервер", "zh": "选择服务器", "es": "Selecciona un servidor",
            "hi": "सर्वर चुनें", "ar": "اختر خادمًا", "fr": "Choisir un serveur",
            "pt": "Selecione um servidor", "de": "Server wählen", "ja": "サーバーを選択",
            "id": "Pilih server", "tr": "Bir sunucu seçin"],
        "Cancel": [
            "ru": "Отмена", "zh": "取消", "es": "Cancelar", "hi": "रद्द करें",
            "ar": "إلغاء", "fr": "Annuler", "pt": "Cancelar", "de": "Abbrechen",
            "ja": "キャンセル", "id": "Batal", "tr": "İptal"],
        "Done": [
            "ru": "Готово", "zh": "完成", "es": "Listo", "hi": "हो गया",
            "ar": "تم", "fr": "Terminé", "pt": "Concluído", "de": "Fertig",
            "ja": "完了", "id": "Selesai", "tr": "Bitti"],
        "Add": [
            "ru": "Добавить", "zh": "添加", "es": "Añadir", "hi": "जोड़ें",
            "ar": "إضافة", "fr": "Ajouter", "pt": "Adicionar", "de": "Hinzufügen",
            "ja": "追加", "id": "Tambah", "tr": "Ekle"],
        "Remove": [
            "ru": "Удалить", "zh": "移除", "es": "Eliminar", "hi": "हटाएं",
            "ar": "إزالة", "fr": "Supprimer", "pt": "Remover", "de": "Entfernen",
            "ja": "削除", "id": "Hapus", "tr": "Kaldır"],
        "Delete": [
            "ru": "Удалить", "zh": "删除", "es": "Borrar", "hi": "हटाएं",
            "ar": "حذف", "fr": "Supprimer", "pt": "Excluir", "de": "Löschen",
            "ja": "削除", "id": "Hapus", "tr": "Sil"],
        "Fetch": [
            "ru": "Загрузить", "zh": "获取", "es": "Obtener", "hi": "लाएं",
            "ar": "جلب", "fr": "Récupérer", "pt": "Buscar", "de": "Abrufen",
            "ja": "取得", "id": "Ambil", "tr": "Getir"],
        "Save": [
            "ru": "Сохранить", "zh": "保存", "es": "Guardar", "hi": "सहेजें",
            "ar": "حفظ", "fr": "Enregistrer", "pt": "Salvar", "de": "Speichern",
            "ja": "保存", "id": "Simpan", "tr": "Kaydet"],

        // MARK: Toolbar / footer
        "Subscription": [
            "ru": "Подписка", "zh": "订阅", "es": "Suscripción", "hi": "सदस्यता",
            "ar": "اشتراك", "fr": "Abonnement", "pt": "Assinatura", "de": "Abonnement",
            "ja": "サブスク", "id": "Langganan", "tr": "Abonelik"],
        "Add Link": [
            "ru": "Добавить ссылку", "zh": "添加链接", "es": "Añadir enlace", "hi": "लिंक जोड़ें",
            "ar": "إضافة رابط", "fr": "Ajouter un lien", "pt": "Adicionar link", "de": "Link hinzufügen",
            "ja": "リンク追加", "id": "Tambah tautan", "tr": "Bağlantı ekle"],
        "Refresh": [
            "ru": "Обновить", "zh": "刷新", "es": "Actualizar", "hi": "ताज़ा करें",
            "ar": "تحديث", "fr": "Actualiser", "pt": "Atualizar", "de": "Aktualisieren",
            "ja": "更新", "id": "Segarkan", "tr": "Yenile"],
        "Test Ping": [
            "ru": "Тест пинга", "zh": "测试延迟", "es": "Probar ping", "hi": "पिंग जांचें",
            "ar": "اختبار البينغ", "fr": "Tester le ping", "pt": "Testar ping", "de": "Ping testen",
            "ja": "Ping測定", "id": "Uji ping", "tr": "Ping testi"],
        "Log": [
            "ru": "Лог", "zh": "日志", "es": "Registro", "hi": "लॉग",
            "ar": "السجل", "fr": "Journal", "pt": "Registro", "de": "Protokoll",
            "ja": "ログ", "id": "Log", "tr": "Günlük"],
        "Settings": [
            "ru": "Настройки", "zh": "设置", "es": "Ajustes", "hi": "सेटिंग्स",
            "ar": "الإعدادات", "fr": "Réglages", "pt": "Configurações", "de": "Einstellungen",
            "ja": "設定", "id": "Pengaturan", "tr": "Ayarlar"],

        // MARK: Search / filter
        "Search servers…": [
            "ru": "Поиск серверов…", "zh": "搜索服务器…", "es": "Buscar servidores…",
            "hi": "सर्वर खोजें…", "ar": "البحث عن خوادم…", "fr": "Rechercher des serveurs…",
            "pt": "Buscar servidores…", "de": "Server suchen…", "ja": "サーバー検索…",
            "id": "Cari server…", "tr": "Sunucu ara…"],
        "Alive": [
            "ru": "Живые", "zh": "在线", "es": "Activos", "hi": "सक्रिय",
            "ar": "نشط", "fr": "Actifs", "pt": "Ativos", "de": "Aktiv",
            "ja": "応答", "id": "Aktif", "tr": "Aktif"],
        "By ping": [
            "ru": "По пингу", "zh": "按延迟", "es": "Por ping", "hi": "पिंग अनुसार",
            "ar": "حسب البينغ", "fr": "Par ping", "pt": "Por ping", "de": "Nach Ping",
            "ja": "Ping順", "id": "Per ping", "tr": "Ping'e göre"],

        // MARK: Empty state
        "No servers yet": [
            "ru": "Пока нет серверов", "zh": "暂无服务器", "es": "Aún no hay servidores",
            "hi": "अभी कोई सर्वर नहीं", "ar": "لا توجد خوادم بعد", "fr": "Aucun serveur",
            "pt": "Nenhum servidor ainda", "de": "Noch keine Server", "ja": "サーバーがありません",
            "id": "Belum ada server", "tr": "Henüz sunucu yok"],
        "Add a subscription or paste a link to get started.": [
            "ru": "Добавьте подписку или вставьте ссылку, чтобы начать.",
            "zh": "添加订阅或粘贴链接以开始。", "es": "Añade una suscripción o pega un enlace para empezar.",
            "hi": "शुरू करने के लिए सदस्यता जोड़ें या लिंक पेस्ट करें।",
            "ar": "أضف اشتراكًا أو ألصق رابطًا للبدء.", "fr": "Ajoutez un abonnement ou collez un lien pour commencer.",
            "pt": "Adicione uma assinatura ou cole um link para começar.",
            "de": "Abonnement hinzufügen oder Link einfügen, um zu starten.",
            "ja": "サブスクを追加するかリンクを貼り付けて開始します。",
            "id": "Tambahkan langganan atau tempel tautan untuk memulai.",
            "tr": "Başlamak için abonelik ekleyin veya bağlantı yapıştırın."],
        "Add Subscription": [
            "ru": "Добавить подписку", "zh": "添加订阅", "es": "Añadir suscripción",
            "hi": "सदस्यता जोड़ें", "ar": "إضافة اشتراك", "fr": "Ajouter un abonnement",
            "pt": "Adicionar assinatura", "de": "Abonnement hinzufügen", "ja": "サブスク追加",
            "id": "Tambah langganan", "tr": "Abonelik ekle"],
        "Paste Link": [
            "ru": "Вставить ссылку", "zh": "粘贴链接", "es": "Pegar enlace",
            "hi": "लिंक पेस्ट करें", "ar": "لصق الرابط", "fr": "Coller le lien",
            "pt": "Colar link", "de": "Link einfügen", "ja": "リンクを貼付",
            "id": "Tempel tautan", "tr": "Bağlantı yapıştır"],

        // MARK: Server group menu
        "Test ping": [
            "ru": "Тест пинга", "zh": "测试延迟", "es": "Probar ping", "hi": "पिंग जांचें",
            "ar": "اختبار البينغ", "fr": "Tester le ping", "pt": "Testar ping", "de": "Ping testen",
            "ja": "Ping測定", "id": "Uji ping", "tr": "Ping testi"],
        "Test ping (group)": [
            "ru": "Тест пинга (группа)", "zh": "测试延迟（组）", "es": "Probar ping (grupo)",
            "hi": "पिंग जांचें (समूह)", "ar": "اختبار البينغ (مجموعة)", "fr": "Tester le ping (groupe)",
            "pt": "Testar ping (grupo)", "de": "Ping testen (Gruppe)", "ja": "Ping測定（グループ）",
            "id": "Uji ping (grup)", "tr": "Ping testi (grup)"],
        "Refresh now": [
            "ru": "Обновить сейчас", "zh": "立即刷新", "es": "Actualizar ahora",
            "hi": "अभी ताज़ा करें", "ar": "تحديث الآن", "fr": "Actualiser maintenant",
            "pt": "Atualizar agora", "de": "Jetzt aktualisieren", "ja": "今すぐ更新",
            "id": "Segarkan sekarang", "tr": "Şimdi yenile"],
        "Auto-update": [
            "ru": "Автообновление", "zh": "自动更新", "es": "Auto-actualizar",
            "hi": "स्वतः अपडेट", "ar": "تحديث تلقائي", "fr": "Mise à jour auto",
            "pt": "Atualização automática", "de": "Auto-Update", "ja": "自動更新",
            "id": "Pembaruan otomatis", "tr": "Otomatik güncelleme"],
        "Switch here": [
            "ru": "Переключить сюда", "zh": "切换到此", "es": "Cambiar aquí",
            "hi": "यहां स्विच करें", "ar": "التبديل هنا", "fr": "Basculer ici",
            "pt": "Mudar para aqui", "de": "Hierhin wechseln", "ja": "ここに切替",
            "id": "Beralih ke sini", "tr": "Buraya geç"],

        // MARK: Add server sheet
        "Add Server(s)": [
            "ru": "Добавить сервер(ы)", "zh": "添加服务器", "es": "Añadir servidor(es)",
            "hi": "सर्वर जोड़ें", "ar": "إضافة خوادم", "fr": "Ajouter des serveurs",
            "pt": "Adicionar servidor(es)", "de": "Server hinzufügen", "ja": "サーバー追加",
            "id": "Tambah server", "tr": "Sunucu ekle"],
        "Paste one or more links (vless://, vmess://, trojan://, ss://). One per line.": [
            "ru": "Вставьте одну или несколько ссылок (vless://, vmess://, trojan://, ss://). По одной на строку.",
            "zh": "粘贴一个或多个链接（vless://、vmess://、trojan://、ss://），每行一个。",
            "es": "Pega uno o más enlaces (vless://, vmess://, trojan://, ss://). Uno por línea.",
            "hi": "एक या अधिक लिंक पेस्ट करें (vless://, vmess://, trojan://, ss://)। प्रति पंक्ति एक।",
            "ar": "ألصق رابطًا واحدًا أو أكثر (vless://، vmess://، trojan://، ss://). واحد لكل سطر.",
            "fr": "Collez un ou plusieurs liens (vless://, vmess://, trojan://, ss://). Un par ligne.",
            "pt": "Cole um ou mais links (vless://, vmess://, trojan://, ss://). Um por linha.",
            "de": "Einen oder mehrere Links einfügen (vless://, vmess://, trojan://, ss://). Einer pro Zeile.",
            "ja": "1つ以上のリンクを貼り付け（vless://、vmess://、trojan://、ss://）。1行に1つ。",
            "id": "Tempel satu atau beberapa tautan (vless://, vmess://, trojan://, ss://). Satu per baris.",
            "tr": "Bir veya daha fazla bağlantı yapıştırın (vless://, vmess://, trojan://, ss://). Her satıra bir tane."],
        "No valid links found. Check the format.": [
            "ru": "Не найдено корректных ссылок. Проверьте формат.",
            "zh": "未找到有效链接。请检查格式。", "es": "No se encontraron enlaces válidos. Comprueba el formato.",
            "hi": "कोई मान्य लिंक नहीं मिला। प्रारूप जांचें।", "ar": "لم يتم العثور على روابط صالحة. تحقق من التنسيق.",
            "fr": "Aucun lien valide trouvé. Vérifiez le format.", "pt": "Nenhum link válido encontrado. Verifique o formato.",
            "de": "Keine gültigen Links gefunden. Format prüfen.", "ja": "有効なリンクがありません。形式を確認してください。",
            "id": "Tidak ada tautan valid. Periksa formatnya.", "tr": "Geçerli bağlantı bulunamadı. Biçimi kontrol edin."],
        "Each subscription becomes its own profile group.": [
            "ru": "Каждая подписка становится отдельной группой профиля.",
            "zh": "每个订阅成为独立的配置组。", "es": "Cada suscripción se convierte en su propio grupo.",
            "hi": "प्रत्येक सदस्यता अपना प्रोफ़ाइल समूह बनती है।", "ar": "يصبح كل اشتراك مجموعة ملف خاصة به.",
            "fr": "Chaque abonnement devient son propre groupe.", "pt": "Cada assinatura vira seu próprio grupo.",
            "de": "Jedes Abonnement wird zu einer eigenen Gruppe.", "ja": "各サブスクは独自のプロファイルグループになります。",
            "id": "Setiap langganan menjadi grup profilnya sendiri.", "tr": "Her abonelik kendi profil grubu olur."],
        "Name (optional)": [
            "ru": "Название (необязательно)", "zh": "名称（可选）", "es": "Nombre (opcional)",
            "hi": "नाम (वैकल्पिक)", "ar": "الاسم (اختياري)", "fr": "Nom (facultatif)",
            "pt": "Nome (opcional)", "de": "Name (optional)", "ja": "名前（任意）",
            "id": "Nama (opsional)", "tr": "Ad (isteğe bağlı)"],

        // MARK: Settings sections
        "Tunnel": [
            "ru": "Туннель", "zh": "隧道", "es": "Túnel", "hi": "टनल",
            "ar": "النفق", "fr": "Tunnel", "pt": "Túnel", "de": "Tunnel",
            "ja": "トンネル", "id": "Terowongan", "tr": "Tünel"],
        "Mode": [
            "ru": "Режим", "zh": "模式", "es": "Modo", "hi": "मोड",
            "ar": "الوضع", "fr": "Mode", "pt": "Modo", "de": "Modus",
            "ja": "モード", "id": "Mode", "tr": "Mod"],
        "Appearance": [
            "ru": "Оформление", "zh": "外观", "es": "Apariencia", "hi": "रूप",
            "ar": "المظهر", "fr": "Apparence", "pt": "Aparência", "de": "Erscheinungsbild",
            "ja": "外観", "id": "Tampilan", "tr": "Görünüm"],
        "Theme": [
            "ru": "Тема", "zh": "主题", "es": "Tema", "hi": "थीम",
            "ar": "السمة", "fr": "Thème", "pt": "Tema", "de": "Design",
            "ja": "テーマ", "id": "Tema", "tr": "Tema"],
        "Language": [
            "ru": "Язык", "zh": "语言", "es": "Idioma", "hi": "भाषा",
            "ar": "اللغة", "fr": "Langue", "pt": "Idioma", "de": "Sprache",
            "ja": "言語", "id": "Bahasa", "tr": "Dil"],
        "Subscriptions": [
            "ru": "Подписки", "zh": "订阅", "es": "Suscripciones", "hi": "सदस्यताएं",
            "ar": "الاشتراكات", "fr": "Abonnements", "pt": "Assinaturas", "de": "Abonnements",
            "ja": "サブスク", "id": "Langganan", "tr": "Abonelikler"],
        "Auto-update subscriptions": [
            "ru": "Автообновление подписок", "zh": "自动更新订阅", "es": "Auto-actualizar suscripciones",
            "hi": "सदस्यताएं स्वतः अपडेट करें", "ar": "تحديث الاشتراكات تلقائيًا", "fr": "Mettre à jour les abonnements auto",
            "pt": "Atualizar assinaturas automaticamente", "de": "Abos automatisch aktualisieren",
            "ja": "サブスクを自動更新", "id": "Perbarui langganan otomatis", "tr": "Abonelikleri otomatik güncelle"],
        "Send HWID with subscription requests": [
            "ru": "Отправлять HWID с запросами подписки", "zh": "订阅请求附带 HWID", "es": "Enviar HWID con solicitudes de suscripción",
            "hi": "सदस्यता अनुरोधों के साथ HWID भेजें", "ar": "إرسال HWID مع طلبات الاشتراك", "fr": "Envoyer le HWID avec les demandes d'abonnement",
            "pt": "Enviar HWID com solicitações de assinatura", "de": "HWID mit Abo-Anfragen senden",
            "ja": "サブスクリクエストにHWIDを送信", "id": "Kirim HWID dengan permintaan langganan", "tr": "Abonelik istekleriyle HWID gönder"],
        "Identifies this device to providers that require it.": [
            "ru": "Идентифицирует устройство для провайдеров, которым это требуется.", "zh": "为需要识别的提供商标识此设备。", "es": "Identifica este dispositivo para los proveedores que lo requieren.",
            "hi": "इस डिवाइस को आवश्यक प्रदाताओं के लिए पहचानता है।", "ar": "يحدد هذا الجهاز للمزودين الذين يتطلبون ذلك.", "fr": "Identifie cet appareil auprès des fournisseurs qui l'exigent.",
            "pt": "Identifica este dispositivo para provedores que exigem.", "de": "Identifiziert dieses Gerät bei Anbietern, die dies verlangen.",
            "ja": "必要なプロバイダーにこのデバイスを識別させます。", "id": "Mengidentifikasi perangkat ini untuk penyedia yang memerlukannya.", "tr": "Bu cihazı gerektiren sağlayıcılar için tanımlar."],
        "Window": [
            "ru": "Окно", "zh": "窗口", "es": "Ventana", "hi": "विंडो",
            "ar": "النافذة", "fr": "Fenêtre", "pt": "Janela", "de": "Fenster",
            "ja": "ウィンドウ", "id": "Jendela", "tr": "Pencere"],
        "Close button hides to menu bar": [
            "ru": "Кнопка закрытия сворачивает в меню-бар",
            "zh": "关闭按钮隐藏到菜单栏", "es": "El botón cerrar oculta en la barra de menús",
            "hi": "बंद बटन मेन्यू बार में छुपाता है", "ar": "زر الإغلاق يخفي إلى شريط القوائم",
            "fr": "Le bouton fermer masque dans la barre de menus", "pt": "Botão fechar oculta na barra de menus",
            "de": "Schließen-Knopf blendet in Menüleiste aus", "ja": "閉じるボタンでメニューバーに格納",
            "id": "Tombol tutup sembunyi ke bilah menu", "tr": "Kapat düğmesi menü çubuğuna gizler"],
        "SOCKS port": [
            "ru": "Порт SOCKS", "zh": "SOCKS 端口", "es": "Puerto SOCKS", "hi": "SOCKS पोर्ट",
            "ar": "منفذ SOCKS", "fr": "Port SOCKS", "pt": "Porta SOCKS", "de": "SOCKS-Port",
            "ja": "SOCKSポート", "id": "Port SOCKS", "tr": "SOCKS portu"],
        "HTTP port": [
            "ru": "Порт HTTP", "zh": "HTTP 端口", "es": "Puerto HTTP", "hi": "HTTP पोर्ट",
            "ar": "منفذ HTTP", "fr": "Port HTTP", "pt": "Porta HTTP", "de": "HTTP-Port",
            "ja": "HTTPポート", "id": "Port HTTP", "tr": "HTTP portu"],
        "Log level": [
            "ru": "Уровень логов", "zh": "日志级别", "es": "Nivel de registro", "hi": "लॉग स्तर",
            "ar": "مستوى السجل", "fr": "Niveau de journal", "pt": "Nível de log", "de": "Log-Level",
            "ja": "ログレベル", "id": "Tingkat log", "tr": "Günlük düzeyi"],
        "Auto-connect on launch": [
            "ru": "Автоподключение при запуске", "zh": "启动时自动连接",
            "es": "Conectar al iniciar", "hi": "लॉन्च पर स्वतः कनेक्ट",
            "ar": "اتصال تلقائي عند البدء", "fr": "Connexion auto au démarrage",
            "pt": "Conectar ao iniciar", "de": "Auto-Verbindung beim Start",
            "ja": "起動時に自動接続", "id": "Sambung otomatis saat mulai",
            "tr": "Başlangıçta otomatik bağlan"],
        "Helper installed": [
            "ru": "Хелпер установлен", "zh": "助手已安装", "es": "Asistente instalado",
            "hi": "हेल्पर स्थापित", "ar": "تم تثبيت المساعد", "fr": "Assistant installé",
            "pt": "Auxiliar instalado", "de": "Helfer installiert", "ja": "ヘルパー導入済み",
            "id": "Helper terpasang", "tr": "Yardımcı kuruldu"],
        "Helper not installed": [
            "ru": "Хелпер не установлен", "zh": "助手未安装", "es": "Asistente no instalado",
            "hi": "हेल्पर स्थापित नहीं", "ar": "المساعد غير مثبت", "fr": "Assistant non installé",
            "pt": "Auxiliar não instalado", "de": "Helfer nicht installiert", "ja": "ヘルパー未導入",
            "id": "Helper belum terpasang", "tr": "Yardımcı kurulu değil"],
        "Install": [
            "ru": "Установить", "zh": "安装", "es": "Instalar", "hi": "इंस्टॉल",
            "ar": "تثبيت", "fr": "Installer", "pt": "Instalar", "de": "Installieren",
            "ja": "インストール", "id": "Pasang", "tr": "Kur"],

        // MARK: Menu bar
        "Open Window": [
            "ru": "Открыть окно", "zh": "打开窗口", "es": "Abrir ventana", "hi": "विंडो खोलें",
            "ar": "فتح النافذة", "fr": "Ouvrir la fenêtre", "pt": "Abrir janela", "de": "Fenster öffnen",
            "ja": "ウィンドウを開く", "id": "Buka jendela", "tr": "Pencereyi aç"],
        "Quit Veil": [
            "ru": "Выйти из Veil", "zh": "退出 Veil", "es": "Salir de Veil", "hi": "Veil छोड़ें",
            "ar": "إنهاء Veil", "fr": "Quitter Veil", "pt": "Sair do Veil", "de": "Veil beenden",
            "ja": "Veilを終了", "id": "Keluar dari Veil", "tr": "Veil'den çık"],

        // MARK: Routing
        "Routing": [
            "ru": "Маршрутизация", "zh": "路由", "es": "Enrutamiento", "hi": "रूटिंग",
            "ar": "التوجيه", "fr": "Routage", "pt": "Roteamento", "de": "Routing",
            "ja": "ルーティング", "id": "Perutean", "tr": "Yönlendirme"],
        "Configure…": [
            "ru": "Настроить…", "zh": "配置…", "es": "Configurar…", "hi": "कॉन्फ़िगर…",
            "ar": "تكوين…", "fr": "Configurer…", "pt": "Configurar…", "de": "Konfigurieren…",
            "ja": "設定…", "id": "Konfigurasi…", "tr": "Yapılandır…"],
        "Preset": [
            "ru": "Пресет", "zh": "预设", "es": "Preajuste", "hi": "प्रीसेट",
            "ar": "إعداد مسبق", "fr": "Préréglage", "pt": "Predefinição", "de": "Voreinstellung",
            "ja": "プリセット", "id": "Praatur", "tr": "Önayar"],
        "Block ads & trackers": [
            "ru": "Блокировать рекламу и трекеры", "zh": "屏蔽广告和追踪器",
            "es": "Bloquear anuncios y rastreadores", "hi": "विज्ञापन और ट्रैकर ब्लॉक करें",
            "ar": "حظر الإعلانات والمتتبعات", "fr": "Bloquer pubs et traqueurs",
            "pt": "Bloquear anúncios e rastreadores", "de": "Werbung & Tracker blockieren",
            "ja": "広告とトラッカーをブロック", "id": "Blokir iklan & pelacak",
            "tr": "Reklam ve izleyicileri engelle"],
        "Rule database": [
            "ru": "База правил", "zh": "规则数据库", "es": "Base de reglas", "hi": "नियम डेटाबेस",
            "ar": "قاعدة القواعد", "fr": "Base de règles", "pt": "Base de regras", "de": "Regeldatenbank",
            "ja": "ルールDB", "id": "Basis aturan", "tr": "Kural veritabanı"],
        "Rule database (geosite / geoip)": [
            "ru": "База правил (geosite / geoip)", "zh": "规则数据库（geosite / geoip）",
            "es": "Base de reglas (geosite / geoip)", "hi": "नियम डेटाबेस (geosite / geoip)",
            "ar": "قاعدة القواعد (geosite / geoip)", "fr": "Base de règles (geosite / geoip)",
            "pt": "Base de regras (geosite / geoip)", "de": "Regeldatenbank (geosite / geoip)",
            "ja": "ルールDB（geosite / geoip）", "id": "Basis aturan (geosite / geoip)",
            "tr": "Kural veritabanı (geosite / geoip)"],
        "Downloading…": [
            "ru": "Загрузка…", "zh": "下载中…", "es": "Descargando…", "hi": "डाउनलोड हो रहा है…",
            "ar": "جارٍ التنزيل…", "fr": "Téléchargement…", "pt": "Baixando…", "de": "Lädt herunter…",
            "ja": "ダウンロード中…", "id": "Mengunduh…", "tr": "İndiriliyor…"],
        "Updated": [
            "ru": "Обновлено", "zh": "已更新", "es": "Actualizado", "hi": "अपडेट किया गया",
            "ar": "تم التحديث", "fr": "Mis à jour", "pt": "Atualizado", "de": "Aktualisiert",
            "ja": "更新済み", "id": "Diperbarui", "tr": "Güncellendi"],
        "Not downloaded": [
            "ru": "Не загружено", "zh": "未下载", "es": "No descargado", "hi": "डाउनलोड नहीं किया",
            "ar": "لم يتم التنزيل", "fr": "Non téléchargé", "pt": "Não baixado", "de": "Nicht heruntergeladen",
            "ja": "未ダウンロード", "id": "Belum diunduh", "tr": "İndirilmedi"],
        "Download": [
            "ru": "Загрузить", "zh": "下载", "es": "Descargar", "hi": "डाउनलोड",
            "ar": "تنزيل", "fr": "Télécharger", "pt": "Baixar", "de": "Herunterladen",
            "ja": "ダウンロード", "id": "Unduh", "tr": "İndir"],
        "Update": [
            "ru": "Обновить", "zh": "更新", "es": "Actualizar", "hi": "अपडेट",
            "ar": "تحديث", "fr": "Mettre à jour", "pt": "Atualizar", "de": "Aktualisieren",
            "ja": "更新", "id": "Perbarui", "tr": "Güncelle"],
        "This preset needs the rule database. Download it to use geosite/geoip rules.": [
            "ru": "Этому пресету нужна база правил. Загрузите её для geosite/geoip.",
            "zh": "此预设需要规则数据库。下载后才能使用 geosite/geoip 规则。",
            "es": "Este preajuste necesita la base de reglas. Descárgala para usar geosite/geoip.",
            "hi": "इस प्रीसेट को नियम डेटाबेस चाहिए। geosite/geoip नियमों के लिए डाउनलोड करें।",
            "ar": "يحتاج هذا الإعداد إلى قاعدة القواعد. نزّلها لاستخدام قواعد geosite/geoip.",
            "fr": "Ce préréglage nécessite la base de règles. Téléchargez-la pour geosite/geoip.",
            "pt": "Esta predefinição precisa da base de regras. Baixe-a para usar geosite/geoip.",
            "de": "Diese Voreinstellung benötigt die Regeldatenbank. Lade sie für geosite/geoip herunter.",
            "ja": "このプリセットにはルールDBが必要です。geosite/geoipルールのためにダウンロードしてください。",
            "id": "Praatur ini membutuhkan basis aturan. Unduh untuk memakai aturan geosite/geoip.",
            "tr": "Bu önayar kural veritabanı gerektirir. geosite/geoip için indirin."],
        "Downloaded from GitHub. geosite matches domains, geoip matches IPs by country.": [
            "ru": "Загружается с GitHub. geosite — домены, geoip — IP по странам.",
            "zh": "从 GitHub 下载。geosite 匹配域名，geoip 按国家匹配 IP。",
            "es": "Descargado de GitHub. geosite coincide con dominios, geoip con IP por país.",
            "hi": "GitHub से डाउनलोड। geosite डोमेन, geoip देश के अनुसार IP मैच करता है।",
            "ar": "يتم التنزيل من GitHub. geosite يطابق النطاقات، geoip يطابق IP حسب الدولة.",
            "fr": "Téléchargé depuis GitHub. geosite correspond aux domaines, geoip aux IP par pays.",
            "pt": "Baixado do GitHub. geosite corresponde a domínios, geoip a IPs por país.",
            "de": "Von GitHub geladen. geosite trifft Domains, geoip trifft IPs nach Land.",
            "ja": "GitHubからダウンロード。geositeはドメイン、geoipは国別IPに一致。",
            "id": "Diunduh dari GitHub. geosite cocok dengan domain, geoip dengan IP per negara.",
            "tr": "GitHub'dan indirilir. geosite alan adlarıyla, geoip ülkeye göre IP'lerle eşleşir."],
        "No custom rules. Add one below.": [
            "ru": "Нет своих правил. Добавьте ниже.", "zh": "没有自定义规则。在下方添加。",
            "es": "Sin reglas personalizadas. Añade una abajo.", "hi": "कोई कस्टम नियम नहीं। नीचे जोड़ें।",
            "ar": "لا توجد قواعد مخصصة. أضف واحدة أدناه.", "fr": "Aucune règle personnalisée. Ajoutez-en une ci-dessous.",
            "pt": "Sem regras personalizadas. Adicione uma abaixo.", "de": "Keine eigenen Regeln. Unten hinzufügen.",
            "ja": "カスタムルールがありません。下に追加してください。", "id": "Tidak ada aturan khusus. Tambah di bawah.",
            "tr": "Özel kural yok. Aşağıdan ekleyin."],
        "Add rule": [
            "ru": "Добавить правило", "zh": "添加规则", "es": "Añadir regla", "hi": "नियम जोड़ें",
            "ar": "إضافة قاعدة", "fr": "Ajouter une règle", "pt": "Adicionar regra", "de": "Regel hinzufügen",
            "ja": "ルールを追加", "id": "Tambah aturan", "tr": "Kural ekle"],
        "Custom rules (top to bottom, first match wins)": [
            "ru": "Свои правила (сверху вниз, срабатывает первое)",
            "zh": "自定义规则（自上而下，首条匹配生效）",
            "es": "Reglas personalizadas (de arriba abajo, gana la primera)",
            "hi": "कस्टम नियम (ऊपर से नीचे, पहला मैच लागू)",
            "ar": "قواعد مخصصة (من الأعلى للأسفل، الأول يفوز)",
            "fr": "Règles personnalisées (de haut en bas, la première gagne)",
            "pt": "Regras personalizadas (de cima para baixo, vence a primeira)",
            "de": "Eigene Regeln (oben nach unten, erste Übereinstimmung gewinnt)",
            "ja": "カスタムルール（上から下へ、最初の一致が有効）",
            "id": "Aturan khusus (atas ke bawah, cocok pertama menang)",
            "tr": "Özel kurallar (yukarıdan aşağıya, ilk eşleşme kazanır)"],
        "Domains: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.": [
            "ru": "Домены: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private.",
            "zh": "域名：example.com、domain:example.com、geosite:category-ads-all、keyword:google。IP：1.2.3.0/24、geoip:cn、geoip:private。",
            "es": "Dominios: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.",
            "hi": "डोमेन: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private.",
            "ar": "النطاقات: example.com، domain:example.com، geosite:category-ads-all، keyword:google. IP: 1.2.3.0/24، geoip:cn، geoip:private.",
            "fr": "Domaines : example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP : 1.2.3.0/24, geoip:cn, geoip:private.",
            "pt": "Domínios: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.",
            "de": "Domains: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.",
            "ja": "ドメイン: example.com、domain:example.com、geosite:category-ads-all、keyword:google。IP: 1.2.3.0/24、geoip:cn、geoip:private。",
            "id": "Domain: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private.",
            "tr": "Alan adları: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private."],
        "Rule name": [
            "ru": "Название правила", "zh": "规则名称", "es": "Nombre de regla", "hi": "नियम नाम",
            "ar": "اسم القاعدة", "fr": "Nom de la règle", "pt": "Nome da regra", "de": "Regelname",
            "ja": "ルール名", "id": "Nama aturan", "tr": "Kural adı"],
        "Domains": [
            "ru": "Домены", "zh": "域名", "es": "Dominios", "hi": "डोमेन",
            "ar": "النطاقات", "fr": "Domaines", "pt": "Domínios", "de": "Domains",
            "ja": "ドメイン", "id": "Domain", "tr": "Alan adları"],
        "IPs / CIDR": [
            "ru": "IP / CIDR", "zh": "IP / CIDR", "es": "IP / CIDR", "hi": "IP / CIDR",
            "ar": "IP / CIDR", "fr": "IP / CIDR", "pt": "IP / CIDR", "de": "IP / CIDR",
            "ja": "IP / CIDR", "id": "IP / CIDR", "tr": "IP / CIDR"],
        "Port": [
            "ru": "Порт", "zh": "端口", "es": "Puerto", "hi": "पोर्ट",
            "ar": "المنفذ", "fr": "Port", "pt": "Porta", "de": "Port",
            "ja": "ポート", "id": "Port", "tr": "Port"],
        "Reconnect to apply routing changes.": [
            "ru": "Переподключитесь, чтобы применить изменения маршрутизации.",
            "zh": "重新连接以应用路由更改。", "es": "Reconecta para aplicar los cambios de enrutamiento.",
            "hi": "रूटिंग परिवर्तन लागू करने के लिए फिर से कनेक्ट करें।", "ar": "أعد الاتصال لتطبيق تغييرات التوجيه.",
            "fr": "Reconnectez-vous pour appliquer les changements de routage.", "pt": "Reconecte para aplicar as alterações de roteamento.",
            "de": "Neu verbinden, um Routing-Änderungen anzuwenden.", "ja": "ルーティングの変更を適用するには再接続してください。",
            "id": "Sambungkan ulang untuk menerapkan perubahan perutean.", "tr": "Yönlendirme değişikliklerini uygulamak için yeniden bağlanın."],

        // MARK: Manual selection / deletion
        "Select": [
            "ru": "Выбрать", "zh": "选择", "es": "Seleccionar", "hi": "चुनें",
            "ar": "تحديد", "fr": "Sélectionner", "pt": "Selecionar", "de": "Auswählen",
            "ja": "選択", "id": "Pilih", "tr": "Seç"],
        "Select All": [
            "ru": "Выбрать все", "zh": "全选", "es": "Seleccionar todo", "hi": "सभी चुनें",
            "ar": "تحديد الكل", "fr": "Tout sélectionner", "pt": "Selecionar tudo", "de": "Alle auswählen",
            "ja": "すべて選択", "id": "Pilih semua", "tr": "Tümünü seç"],
        "Deselect All": [
            "ru": "Снять выбор", "zh": "取消全选", "es": "Deseleccionar todo", "hi": "चयन हटाएं",
            "ar": "إلغاء تحديد الكل", "fr": "Tout désélectionner", "pt": "Desmarcar tudo", "de": "Auswahl aufheben",
            "ja": "選択解除", "id": "Batalkan semua", "tr": "Seçimi kaldır"],
        "Delete Selected": [
            "ru": "Удалить выбранные", "zh": "删除所选", "es": "Eliminar seleccionados",
            "hi": "चयनित हटाएं", "ar": "حذف المحدد", "fr": "Supprimer la sélection",
            "pt": "Excluir selecionados", "de": "Auswahl löschen", "ja": "選択を削除",
            "id": "Hapus terpilih", "tr": "Seçilenleri sil"],
        "Manual": [
            "ru": "Вручную", "zh": "手动", "es": "Manual", "hi": "मैनुअल",
            "ar": "يدوي", "fr": "Manuel", "pt": "Manual", "de": "Manuell",
            "ja": "手動", "id": "Manual", "tr": "Manuel"],
        "System": [
            "ru": "Системный", "zh": "系统", "es": "Sistema", "hi": "सिस्टम",
            "ar": "النظام", "fr": "Système", "pt": "Sistema", "de": "System",
            "ja": "システム", "id": "Sistem", "tr": "Sistem"],

        // MARK: Enum titles shown in pickers (LogLevel, RoutingPreset, AppAppearance, RuleOutbound, GeoAssetSource)
        "Debug": [
            "ru": "Отладка", "zh": "调试", "es": "Depuración", "hi": "डिबग",
            "ar": "تصحيح", "fr": "Débogage", "pt": "Depuração", "de": "Debug",
            "ja": "デバッグ", "id": "Debug", "tr": "Hata ayıklama"],
        "Info": [
            "ru": "Инфо", "zh": "信息", "es": "Información", "hi": "जानकारी",
            "ar": "معلومات", "fr": "Info", "pt": "Informação", "de": "Info",
            "ja": "情報", "id": "Info", "tr": "Bilgi"],
        "Warning": [
            "ru": "Предупреждения", "zh": "警告", "es": "Advertencia", "hi": "चेतावनी",
            "ar": "تحذير", "fr": "Avertissement", "pt": "Aviso", "de": "Warnung",
            "ja": "警告", "id": "Peringatan", "tr": "Uyarı"],
        "Error": [
            "ru": "Ошибки", "zh": "错误", "es": "Error", "hi": "त्रुटि",
            "ar": "خطأ", "fr": "Erreur", "pt": "Erro", "de": "Fehler",
            "ja": "エラー", "id": "Kesalahan", "tr": "Hata"],
        "None": [
            "ru": "Нет", "zh": "无", "es": "Ninguno", "hi": "कोई नहीं",
            "ar": "بدون", "fr": "Aucun", "pt": "Nenhum", "de": "Keine",
            "ja": "なし", "id": "Tidak ada", "tr": "Yok"],
        "Global": [
            "ru": "Глобально", "zh": "全局", "es": "Global", "hi": "ग्लोबल",
            "ar": "عام", "fr": "Global", "pt": "Global", "de": "Global",
            "ja": "グローバル", "id": "Global", "tr": "Genel"],
        "Bypass LAN": [
            "ru": "В обход LAN", "zh": "绕过局域网", "es": "Omitir LAN", "hi": "LAN बायपास",
            "ar": "تجاوز الشبكة المحلية", "fr": "Contourner le LAN", "pt": "Ignorar LAN", "de": "LAN umgehen",
            "ja": "LAN をバイパス", "id": "Lewati LAN", "tr": "LAN'ı atla"],
        "Bypass China": [
            "ru": "В обход Китая", "zh": "绕过中国", "es": "Omitir China", "hi": "चीन बायपास",
            "ar": "تجاوز الصين", "fr": "Contourner la Chine", "pt": "Ignorar China", "de": "China umgehen",
            "ja": "中国をバイパス", "id": "Lewati Tiongkok", "tr": "Çin'i atla"],
        "Bypass Russia": [
            "ru": "В обход России", "zh": "绕过俄罗斯", "es": "Omitir Rusia", "hi": "रूस बायपास",
            "ar": "تجاوز روسيا", "fr": "Contourner la Russie", "pt": "Ignorar Rússia", "de": "Russland umgehen",
            "ja": "ロシアをバイパス", "id": "Lewati Rusia", "tr": "Rusya'yı atla"],
        "Custom": [
            "ru": "Свои", "zh": "自定义", "es": "Personalizado", "hi": "कस्टम",
            "ar": "مخصص", "fr": "Personnalisé", "pt": "Personalizado", "de": "Eigene",
            "ja": "カスタム", "id": "Kustom", "tr": "Özel"],
        "Light": [
            "ru": "Светлая", "zh": "浅色", "es": "Claro", "hi": "लाइट",
            "ar": "فاتح", "fr": "Clair", "pt": "Claro", "de": "Hell",
            "ja": "ライト", "id": "Terang", "tr": "Açık"],
        "Dark": [
            "ru": "Тёмная", "zh": "深色", "es": "Oscuro", "hi": "डार्क",
            "ar": "داكن", "fr": "Sombre", "pt": "Escuro", "de": "Dunkel",
            "ja": "ダーク", "id": "Gelap", "tr": "Koyu"],
        "Proxy": [
            "ru": "Прокси", "zh": "代理", "es": "Proxy", "hi": "प्रॉक्सी",
            "ar": "الوكيل", "fr": "Proxy", "pt": "Proxy", "de": "Proxy",
            "ja": "プロキシ", "id": "Proxy", "tr": "Proxy"],
        "Direct": [
            "ru": "Напрямую", "zh": "直连", "es": "Directo", "hi": "सीधा",
            "ar": "مباشر", "fr": "Direct", "pt": "Direto", "de": "Direkt",
            "ja": "直接", "id": "Langsung", "tr": "Doğrudan"],
        "Block": [
            "ru": "Блокировать", "zh": "阻止", "es": "Bloquear", "hi": "ब्लॉक",
            "ar": "حظر", "fr": "Bloquer", "pt": "Bloquear", "de": "Blockieren",
            "ja": "ブロック", "id": "Blokir", "tr": "Engelle"],
        "All traffic through the proxy.": [
            "ru": "Весь трафик через прокси.", "zh": "所有流量走代理。", "es": "Todo el tráfico por el proxy.", "hi": "सारा ट्रैफ़िक प्रॉक्सी से।",
            "ar": "كل حركة البيانات عبر الوكيل.", "fr": "Tout le trafic passe par le proxy.", "pt": "Todo o tráfego pelo proxy.", "de": "Gesamter Verkehr über den Proxy.",
            "ja": "すべての通信をプロキシ経由にします。", "id": "Semua lalu lintas lewat proxy.", "tr": "Tüm trafik proxy üzerinden."],
        "Proxy everything except local/LAN addresses.": [
            "ru": "Всё через прокси, кроме локальных адресов.", "zh": "除本地/局域网地址外全部走代理。", "es": "Todo por el proxy salvo las direcciones locales/LAN.", "hi": "लोकल/LAN पतों को छोड़कर सब प्रॉक्सी से।",
            "ar": "كل شيء عبر الوكيل عدا العناوين المحلية.", "fr": "Tout via le proxy sauf les adresses locales/LAN.", "pt": "Tudo pelo proxy exceto endereços locais/LAN.", "de": "Alles über den Proxy außer lokalen/LAN-Adressen.",
            "ja": "ローカル/LAN アドレス以外をプロキシ経由にします。", "id": "Semua lewat proxy kecuali alamat lokal/LAN.", "tr": "Yerel/LAN adresleri dışında her şey proxy üzerinden."],
        "Mainland China sites & LAN go direct, rest via proxy.": [
            "ru": "Сайты Китая и локальная сеть — напрямую, остальное через прокси.", "zh": "中国大陆站点与局域网直连，其余走代理。", "es": "Sitios de China continental y LAN directos, el resto por proxy.", "hi": "मुख्यभूमि चीन की साइटें और LAN सीधे, बाकी प्रॉक्सी से।",
            "ar": "مواقع الصين والشبكة المحلية مباشرة، والباقي عبر الوكيل.", "fr": "Sites de Chine continentale et LAN en direct, le reste via le proxy.", "pt": "Sites da China continental e LAN diretos, o resto pelo proxy.", "de": "Festlandchina-Seiten und LAN direkt, der Rest über den Proxy.",
            "ja": "中国本土のサイトと LAN は直接接続、それ以外はプロキシ経由。", "id": "Situs Tiongkok daratan dan LAN langsung, sisanya lewat proxy.", "tr": "Çin anakarası siteleri ve LAN doğrudan, gerisi proxy üzerinden."],
        "Russian & .ru-gov sites go direct, rest via proxy.": [
            "ru": "Российские и госсайты — напрямую, остальное через прокси.", "zh": "俄罗斯及 .ru 政府站点直连，其余走代理。", "es": "Sitios rusos y gubernamentales directos, el resto por proxy.", "hi": "रूसी और सरकारी साइटें सीधे, बाकी प्रॉक्सी से।",
            "ar": "المواقع الروسية والحكومية مباشرة، والباقي عبر الوكيل.", "fr": "Sites russes et gouvernementaux en direct, le reste via le proxy.", "pt": "Sites russos e governamentais diretos, o resto pelo proxy.", "de": "Russische und Regierungsseiten direkt, der Rest über den Proxy.",
            "ja": "ロシアと政府系サイトは直接接続、それ以外はプロキシ経由。", "id": "Situs Rusia dan pemerintah langsung, sisanya lewat proxy.", "tr": "Rus ve devlet siteleri doğrudan, gerisi proxy üzerinden."],
        "Your own ordered rule list.": [
            "ru": "Ваш собственный упорядоченный список правил.", "zh": "你自己排序的规则列表。", "es": "Tu propia lista ordenada de reglas.", "hi": "आपकी अपनी क्रमबद्ध नियम सूची।",
            "ar": "قائمة قواعدك المرتّبة الخاصة.", "fr": "Votre propre liste de règles ordonnée.", "pt": "Sua própria lista ordenada de regras.", "de": "Ihre eigene, geordnete Regelliste.",
            "ja": "独自の順序付きルールリスト。", "id": "Daftar aturan berurutan milik Anda.", "tr": "Kendi sıralı kural listeniz."],
        "Loyalsoldier (global + CN)": [
            "ru": "Loyalsoldier (мир + Китай)", "zh": "Loyalsoldier（全球 + 中国）", "es": "Loyalsoldier (global + CN)", "hi": "Loyalsoldier (वैश्विक + CN)",
            "ar": "Loyalsoldier (عالمي + الصين)", "fr": "Loyalsoldier (monde + CN)", "pt": "Loyalsoldier (global + CN)", "de": "Loyalsoldier (global + CN)",
            "ja": "Loyalsoldier（全世界 + 中国）", "id": "Loyalsoldier (global + CN)", "tr": "Loyalsoldier (küresel + ÇH)"],
        "runetfreedom (RU)": [
            "ru": "runetfreedom (Россия)", "zh": "runetfreedom（俄罗斯）", "es": "runetfreedom (Rusia)", "hi": "runetfreedom (रूस)",
            "ar": "runetfreedom (روسيا)", "fr": "runetfreedom (Russie)", "pt": "runetfreedom (Rússia)", "de": "runetfreedom (Russland)",
            "ja": "runetfreedom（ロシア）", "id": "runetfreedom (Rusia)", "tr": "runetfreedom (Rusya)"],
        "v2fly (official)": [
            "ru": "v2fly (официальный)", "zh": "v2fly（官方）", "es": "v2fly (oficial)", "hi": "v2fly (आधिकारिक)",
            "ar": "v2fly (رسمي)", "fr": "v2fly (officiel)", "pt": "v2fly (oficial)", "de": "v2fly (offiziell)",
            "ja": "v2fly（公式）", "id": "v2fly (resmi)", "tr": "v2fly (resmî)"],
        "Custom URLs": [
            "ru": "Свои ссылки", "zh": "自定义地址", "es": "URL personalizadas", "hi": "कस्टम URL",
            "ar": "روابط مخصصة", "fr": "URL personnalisées", "pt": "URLs personalizadas", "de": "Eigene URLs",
            "ja": "カスタム URL", "id": "URL kustom", "tr": "Özel adresler"],

        // MARK: iOS app
        "About": [
            "ru": "О программе", "zh": "关于", "es": "Acerca de", "hi": "परिचय",
            "ar": "حول", "fr": "À propos", "pt": "Sobre", "de": "Über",
            "ja": "情報", "id": "Tentang", "tr": "Hakkında"],
        "App version": [
            "ru": "Версия приложения", "zh": "应用版本", "es": "Versión de la app", "hi": "ऐप संस्करण",
            "ar": "إصدار التطبيق", "fr": "Version de l'app", "pt": "Versão do app", "de": "App-Version",
            "ja": "アプリバージョン", "id": "Versi aplikasi", "tr": "Uygulama sürümü"],
        "Block ads": [
            "ru": "Блокировать рекламу", "zh": "拦截广告", "es": "Bloquear anuncios", "hi": "विज्ञापन ब्लॉक करें",
            "ar": "حظر الإعلانات", "fr": "Bloquer les pubs", "pt": "Bloquear anúncios", "de": "Werbung blockieren",
            "ja": "広告をブロック", "id": "Blokir iklan", "tr": "Reklamları engelle"],
        "Blocking": [
            "ru": "Блокировка", "zh": "拦截", "es": "Bloqueo", "hi": "ब्लॉकिंग",
            "ar": "الحظر", "fr": "Blocage", "pt": "Bloqueio", "de": "Blockieren",
            "ja": "ブロック", "id": "Pemblokiran", "tr": "Engelleme"],
        "Changes apply the next time you connect or switch servers.": [
            "ru": "Изменения применятся при следующем подключении или смене сервера.", "zh": "更改将在下次连接或切换服务器时生效。", "es": "Los cambios se aplican la próxima vez que te conectes o cambies de servidor.", "hi": "परिवर्तन अगली बार कनेक्ट करने या सर्वर बदलने पर लागू होंगे।",
            "ar": "تُطبَّق التغييرات عند الاتصال التالي أو عند تبديل الخادم.", "fr": "Les modifications s'appliqueront à la prochaine connexion ou au changement de serveur.", "pt": "As alterações serão aplicadas na próxima conexão ou troca de servidor.", "de": "Änderungen gelten beim nächsten Verbinden oder Serverwechsel.",
            "ja": "変更は次回の接続またはサーバー切り替え時に適用されます。", "id": "Perubahan berlaku saat Anda terhubung berikutnya atau berganti server.", "tr": "Değişiklikler bir sonraki bağlantıda veya sunucu değişiminde uygulanır."],
        "Copy link": [
            "ru": "Скопировать ссылку", "zh": "复制链接", "es": "Copiar enlace", "hi": "लिंक कॉपी करें",
            "ar": "نسخ الرابط", "fr": "Copier le lien", "pt": "Copiar link", "de": "Link kopieren",
            "ja": "リンクをコピー", "id": "Salin tautan", "tr": "Bağlantıyı kopyala"],
        "Could not read that image.": [
            "ru": "Не удалось прочитать изображение.", "zh": "无法读取该图片。", "es": "No se pudo leer la imagen.", "hi": "वह छवि पढ़ी नहीं जा सकी।",
            "ar": "تعذّرت قراءة الصورة.", "fr": "Impossible de lire cette image.", "pt": "Não foi possível ler a imagem.", "de": "Bild konnte nicht gelesen werden.",
            "ja": "画像を読み取れませんでした。", "id": "Tidak dapat membaca gambar itu.", "tr": "Görsel okunamadı."],
        "Could not render a QR code for this server.": [
            "ru": "Не удалось создать QR-код для этого сервера.", "zh": "无法为该服务器生成二维码。", "es": "No se pudo generar el código QR de este servidor.", "hi": "इस सर्वर के लिए QR कोड नहीं बनाया जा सका।",
            "ar": "تعذّر إنشاء رمز QR لهذا الخادم.", "fr": "Impossible de générer le QR code pour ce serveur.", "pt": "Não foi possível gerar o QR code deste servidor.", "de": "QR-Code für diesen Server konnte nicht erstellt werden.",
            "ja": "このサーバーの QR コードを生成できませんでした。", "id": "Tidak dapat membuat kode QR untuk server ini.", "tr": "Bu sunucu için QR kod oluşturulamadı."],
        "Custom rules": [
            "ru": "Свои правила", "zh": "自定义规则", "es": "Reglas personalizadas", "hi": "कस्टम नियम",
            "ar": "قواعد مخصصة", "fr": "Règles personnalisées", "pt": "Regras personalizadas", "de": "Eigene Regeln",
            "ja": "カスタムルール", "id": "Aturan kustom", "tr": "Özel kurallar"],
        "Device ID": [
            "ru": "ID устройства", "zh": "设备 ID", "es": "ID del dispositivo", "hi": "डिवाइस आईडी",
            "ar": "معرّف الجهاز", "fr": "Identifiant de l'appareil", "pt": "ID do dispositivo", "de": "Geräte-ID",
            "ja": "デバイス ID", "id": "ID perangkat", "tr": "Cihaz kimliği"],
        "Download geo databases": [
            "ru": "Скачать geo-базы", "zh": "下载 geo 数据库", "es": "Descargar bases geo", "hi": "geo डेटाबेस डाउनलोड करें",
            "ar": "تنزيل قواعد geo", "fr": "Télécharger les bases geo", "pt": "Baixar bases geo", "de": "Geo-Datenbanken laden",
            "ja": "geo データベースをダウンロード", "id": "Unduh basis data geo", "tr": "Geo veritabanlarını indir"],
        "Enabled": [
            "ru": "Включено", "zh": "已启用", "es": "Activada", "hi": "सक्षम",
            "ar": "مفعّل", "fr": "Activée", "pt": "Ativada", "de": "Aktiviert",
            "ja": "有効", "id": "Aktif", "tr": "Etkin"],
        "Every": [
            "ru": "Каждые", "zh": "每", "es": "Cada", "hi": "हर",
            "ar": "كل", "fr": "Toutes les", "pt": "A cada", "de": "Alle",
            "ja": "間隔", "id": "Setiap", "tr": "Her"],
        "Expires": [
            "ru": "Истекает", "zh": "到期", "es": "Vence", "hi": "समाप्ति",
            "ar": "ينتهي", "fr": "Expire", "pt": "Expira", "de": "Läuft ab",
            "ja": "有効期限", "id": "Kedaluwarsa", "tr": "Bitiş"],
        "Failed": [
            "ru": "Ошибка", "zh": "失败", "es": "Error", "hi": "विफल",
            "ar": "فشل", "fr": "Échec", "pt": "Falhou", "de": "Fehlgeschlagen",
            "ja": "失敗", "id": "Gagal", "tr": "Başarısız"],
        "From image…": [
            "ru": "Из изображения…", "zh": "从图片…", "es": "Desde imagen…", "hi": "छवि से…",
            "ar": "من صورة…", "fr": "Depuis une image…", "pt": "De uma imagem…", "de": "Aus Bild…",
            "ja": "画像から…", "id": "Dari gambar…", "tr": "Görselden…"],
        "Geo databases": [
            "ru": "Geo-базы", "zh": "Geo 数据库", "es": "Bases geo", "hi": "Geo डेटाबेस",
            "ar": "قواعد geo", "fr": "Bases geo", "pt": "Bases geo", "de": "Geo-Datenbanken",
            "ja": "geo データベース", "id": "Basis data geo", "tr": "Geo veritabanları"],
        "IPs": [
            "ru": "IP-адреса", "zh": "IP 地址", "es": "IP", "hi": "IP पते",
            "ar": "عناوين IP", "fr": "IP", "pt": "IPs", "de": "IPs",
            "ja": "IP アドレス", "id": "Alamat IP", "tr": "IP adresleri"],
        "IPv6 inside tunnel": [
            "ru": "IPv6 в туннеле", "zh": "隧道内 IPv6", "es": "IPv6 en el túnel", "hi": "टनल में IPv6",
            "ar": "IPv6 داخل النفق", "fr": "IPv6 dans le tunnel", "pt": "IPv6 no túnel", "de": "IPv6 im Tunnel",
            "ja": "トンネル内の IPv6", "id": "IPv6 dalam terowongan", "tr": "Tünel içinde IPv6"],
        "Installed": [
            "ru": "Установлен", "zh": "已安装", "es": "Instalado", "hi": "इंस्टॉल्ड",
            "ar": "مثبَّت", "fr": "Installé", "pt": "Instalado", "de": "Installiert",
            "ja": "インストール済み", "id": "Terpasang", "tr": "Yüklü"],
        "Installed.": [
            "ru": "Установлены.", "zh": "已安装。", "es": "Instaladas.", "hi": "इंस्टॉल्ड।",
            "ar": "مثبَّتة.", "fr": "Installées.", "pt": "Instaladas.", "de": "Installiert.",
            "ja": "インストール済み。", "id": "Terpasang.", "tr": "Yüklü."],
        "Name": [
            "ru": "Название", "zh": "名称", "es": "Nombre", "hi": "नाम",
            "ar": "الاسم", "fr": "Nom", "pt": "Nome", "de": "Name",
            "ja": "名前", "id": "Nama", "tr": "Ad"],
        "Network Extension (all apps)": [
            "ru": "Network Extension (все приложения)", "zh": "Network Extension（所有应用）", "es": "Network Extension (todas las apps)", "hi": "Network Extension (सभी ऐप्स)",
            "ar": "Network Extension (كل التطبيقات)", "fr": "Network Extension (toutes les apps)", "pt": "Network Extension (todos os apps)", "de": "Network Extension (alle Apps)",
            "ja": "Network Extension（全アプリ）", "id": "Network Extension (semua aplikasi)", "tr": "Network Extension (tüm uygulamalar)"],
        "New rule": [
            "ru": "Новое правило", "zh": "新规则", "es": "Nueva regla", "hi": "नया नियम",
            "ar": "قاعدة جديدة", "fr": "Nouvelle règle", "pt": "Nova regra", "de": "Neue Regel",
            "ja": "新しいルール", "id": "Aturan baru", "tr": "Yeni kural"],
        "No QR code found in that image.": [
            "ru": "В изображении нет QR-кода.", "zh": "该图片中未找到二维码。", "es": "No se encontró ningún código QR en la imagen.", "hi": "उस छवि में कोई QR कोड नहीं मिला।",
            "ar": "لم يُعثر على رمز QR في الصورة.", "fr": "Aucun QR code trouvé dans cette image.", "pt": "Nenhum QR code encontrado na imagem.", "de": "Kein QR-Code im Bild gefunden.",
            "ja": "画像に QR コードが見つかりません。", "id": "Tidak ada kode QR pada gambar itu.", "tr": "Görselde QR kod bulunamadı."],
        "No logs yet.": [
            "ru": "Логов пока нет.", "zh": "暂无日志。", "es": "Aún no hay registros.", "hi": "अभी कोई लॉग नहीं।",
            "ar": "لا توجد سجلات بعد.", "fr": "Aucun journal pour l'instant.", "pt": "Ainda não há logs.", "de": "Noch keine Logs.",
            "ja": "ログはまだありません。", "id": "Belum ada log.", "tr": "Henüz günlük yok."],
        "Not a link or subscription URL": [
            "ru": "Это не ссылка и не URL подписки", "zh": "不是链接或订阅地址", "es": "No es un enlace ni una URL de suscripción", "hi": "यह लिंक या सब्सक्रिप्शन URL नहीं है",
            "ar": "ليس رابطًا ولا عنوان اشتراك", "fr": "Ni un lien ni une URL d'abonnement", "pt": "Não é um link nem uma URL de assinatura", "de": "Weder Link noch Abo-URL",
            "ja": "リンクでもサブスクリプション URL でもありません", "id": "Bukan tautan atau URL langganan", "tr": "Bağlantı ya da abonelik adresi değil"],
        "Not installed": [
            "ru": "Не установлен", "zh": "未安装", "es": "No instalado", "hi": "इंस्टॉल नहीं है",
            "ar": "غير مثبَّت", "fr": "Non installé", "pt": "Não instalado", "de": "Nicht installiert",
            "ja": "未インストール", "id": "Belum terpasang", "tr": "Yüklü değil"],
        "Notify on connect": [
            "ru": "Уведомлять о подключении", "zh": "连接时通知", "es": "Notificar al conectar", "hi": "कनेक्ट होने पर सूचित करें",
            "ar": "تنبيه عند الاتصال", "fr": "Notifier à la connexion", "pt": "Notificar ao conectar", "de": "Bei Verbindung benachrichtigen",
            "ja": "接続時に通知", "id": "Beri tahu saat terhubung", "tr": "Bağlanınca bildir"],
        "Outbound": [
            "ru": "Исходящий", "zh": "出站", "es": "Salida", "hi": "आउटबाउंड",
            "ar": "الوجهة", "fr": "Sortie", "pt": "Saída", "de": "Ausgang",
            "ja": "アウトバウンド", "id": "Keluar", "tr": "Çıkış"],
        "Paste a link, subscription URL or config": [
            "ru": "Вставьте ссылку, URL подписки или конфиг", "zh": "粘贴链接、订阅地址或配置", "es": "Pega un enlace, URL de suscripción o configuración", "hi": "लिंक, सब्सक्रिप्शन URL या कॉन्फ़िग पेस्ट करें",
            "ar": "الصق رابطًا أو عنوان اشتراك أو إعدادًا", "fr": "Collez un lien, une URL d'abonnement ou une config", "pt": "Cole um link, URL de assinatura ou config", "de": "Link, Abo-URL oder Config einfügen",
            "ja": "リンク・サブスクリプション URL・設定を貼り付け", "id": "Tempel tautan, URL langganan, atau konfigurasi", "tr": "Bağlantı, abonelik adresi veya yapılandırma yapıştırın"],
        "Paste a server link or a subscription URL to get started.": [
            "ru": "Вставьте ссылку на сервер или URL подписки, чтобы начать.", "zh": "粘贴服务器链接或订阅地址即可开始。", "es": "Pega un enlace de servidor o una URL de suscripción para empezar.", "hi": "शुरू करने के लिए सर्वर लिंक या सब्सक्रिप्शन URL पेस्ट करें।",
            "ar": "الصق رابط خادم أو عنوان اشتراك للبدء.", "fr": "Collez un lien de serveur ou une URL d'abonnement pour commencer.", "pt": "Cole um link de servidor ou uma URL de assinatura para começar.", "de": "Server-Link oder Abo-URL einfügen, um zu starten.",
            "ja": "サーバーのリンクかサブスクリプション URL を貼り付けて始めましょう。", "id": "Tempel tautan server atau URL langganan untuk memulai.", "tr": "Başlamak için bir sunucu bağlantısı veya abonelik adresi yapıştırın."],
        "Paste from clipboard": [
            "ru": "Вставить из буфера", "zh": "从剪贴板粘贴", "es": "Pegar del portapapeles", "hi": "क्लिपबोर्ड से पेस्ट करें",
            "ar": "لصق من الحافظة", "fr": "Coller depuis le presse-papiers", "pt": "Colar da área de transferência", "de": "Aus Zwischenablage einfügen",
            "ja": "クリップボードから貼り付け", "id": "Tempel dari papan klip", "tr": "Panodan yapıştır"],
        "Port (optional)": [
            "ru": "Порт (необязательно)", "zh": "端口（可选）", "es": "Puerto (opcional)", "hi": "पोर्ट (वैकल्पिक)",
            "ar": "المنفذ (اختياري)", "fr": "Port (facultatif)", "pt": "Porta (opcional)", "de": "Port (optional)",
            "ja": "ポート（任意）", "id": "Port (opsional)", "tr": "Bağlantı noktası (isteğe bağlı)"],
        "Remove VPN profile": [
            "ru": "Удалить VPN-профиль", "zh": "删除 VPN 配置", "es": "Eliminar perfil VPN", "hi": "VPN प्रोफ़ाइल हटाएँ",
            "ar": "إزالة ملف VPN", "fr": "Supprimer le profil VPN", "pt": "Remover perfil VPN", "de": "VPN-Profil entfernen",
            "ja": "VPN プロファイルを削除", "id": "Hapus profil VPN", "tr": "VPN profilini kaldır"],
        "Remove VPN profile?": [
            "ru": "Удалить VPN-профиль?", "zh": "删除 VPN 配置？", "es": "¿Eliminar el perfil VPN?", "hi": "VPN प्रोफ़ाइल हटाएँ?",
            "ar": "إزالة ملف VPN؟", "fr": "Supprimer le profil VPN ?", "pt": "Remover perfil VPN?", "de": "VPN-Profil entfernen?",
            "ja": "VPN プロファイルを削除しますか？", "id": "Hapus profil VPN?", "tr": "VPN profili kaldırılsın mı?"],
        "Rules": [
            "ru": "Правила", "zh": "规则", "es": "Reglas", "hi": "नियम",
            "ar": "القواعد", "fr": "Règles", "pt": "Regras", "de": "Regeln",
            "ja": "ルール", "id": "Aturan", "tr": "Kurallar"],
        "Scan camera": [
            "ru": "Сканировать камерой", "zh": "用相机扫描", "es": "Escanear con la cámara", "hi": "कैमरे से स्कैन करें",
            "ar": "المسح بالكاميرا", "fr": "Scanner avec l'appareil photo", "pt": "Escanear com a câmera", "de": "Mit Kamera scannen",
            "ja": "カメラでスキャン", "id": "Pindai dengan kamera", "tr": "Kamerayla tara"],
        "Send device ID (HWID)": [
            "ru": "Отправлять ID устройства (HWID)", "zh": "发送设备 ID (HWID)", "es": "Enviar ID del dispositivo (HWID)", "hi": "डिवाइस आईडी (HWID) भेजें",
            "ar": "إرسال معرّف الجهاز (HWID)", "fr": "Envoyer l'identifiant (HWID)", "pt": "Enviar ID do dispositivo (HWID)", "de": "Geräte-ID (HWID) senden",
            "ja": "デバイス ID (HWID) を送信", "id": "Kirim ID perangkat (HWID)", "tr": "Cihaz kimliğini (HWID) gönder"],
        "Server": [
            "ru": "Сервер", "zh": "服务器", "es": "Servidor", "hi": "सर्वर",
            "ar": "الخادم", "fr": "Serveur", "pt": "Servidor", "de": "Server",
            "ja": "サーバー", "id": "Server", "tr": "Sunucu"],
        "Servers found": [
            "ru": "Найдено серверов", "zh": "找到服务器", "es": "Servidores encontrados", "hi": "सर्वर मिले",
            "ar": "الخوادم الموجودة", "fr": "Serveurs trouvés", "pt": "Servidores encontrados", "de": "Gefundene Server",
            "ja": "見つかったサーバー", "id": "Server ditemukan", "tr": "Bulunan sunucular"],
        "Share": [
            "ru": "Поделиться", "zh": "分享", "es": "Compartir", "hi": "शेयर करें",
            "ar": "مشاركة", "fr": "Partager", "pt": "Compartilhar", "de": "Teilen",
            "ja": "共有", "id": "Bagikan", "tr": "Paylaş"],
        "Show QR code": [
            "ru": "Показать QR-код", "zh": "显示二维码", "es": "Mostrar código QR", "hi": "QR कोड दिखाएँ",
            "ar": "عرض رمز QR", "fr": "Afficher le QR code", "pt": "Mostrar QR code", "de": "QR-Code anzeigen",
            "ja": "QR コードを表示", "id": "Tampilkan kode QR", "tr": "QR kodu göster"],
        "Source": [
            "ru": "Источник", "zh": "来源", "es": "Fuente", "hi": "स्रोत",
            "ar": "المصدر", "fr": "Source", "pt": "Fonte", "de": "Quelle",
            "ja": "ソース", "id": "Sumber", "tr": "Kaynak"],
        "Startup": [
            "ru": "Запуск", "zh": "启动", "es": "Inicio", "hi": "स्टार्टअप",
            "ar": "بدء التشغيل", "fr": "Démarrage", "pt": "Inicialização", "de": "Start",
            "ja": "起動", "id": "Mulai", "tr": "Başlangıç"],
        "Status": [
            "ru": "Статус", "zh": "状态", "es": "Estado", "hi": "स्थिति",
            "ar": "الحالة", "fr": "État", "pt": "Status", "de": "Status",
            "ja": "状態", "id": "Status", "tr": "Durum"],
        "The subscription returned no servers.": [
            "ru": "Подписка не вернула ни одного сервера.", "zh": "订阅未返回任何服务器。", "es": "La suscripción no devolvió servidores.", "hi": "सब्सक्रिप्शन से कोई सर्वर नहीं मिला।",
            "ar": "لم يُرجع الاشتراك أي خادم.", "fr": "L'abonnement n'a renvoyé aucun serveur.", "pt": "A assinatura não retornou servidores.", "de": "Das Abo hat keine Server geliefert.",
            "ja": "サブスクリプションからサーバーが返されませんでした。", "id": "Langganan tidak mengembalikan server.", "tr": "Abonelik hiç sunucu döndürmedi."],
        "Untitled rule": [
            "ru": "Правило без названия", "zh": "未命名规则", "es": "Regla sin nombre", "hi": "बिना नाम का नियम",
            "ar": "قاعدة بلا اسم", "fr": "Règle sans nom", "pt": "Regra sem nome", "de": "Unbenannte Regel",
            "ja": "名称未設定のルール", "id": "Aturan tanpa nama", "tr": "Adsız kural"],
        "VPN profile": [
            "ru": "VPN-профиль", "zh": "VPN 配置", "es": "Perfil VPN", "hi": "VPN प्रोफ़ाइल",
            "ar": "ملف VPN", "fr": "Profil VPN", "pt": "Perfil VPN", "de": "VPN-Profil",
            "ja": "VPN プロファイル", "id": "Profil VPN", "tr": "VPN profili"],
        "Xray core": [
            "ru": "Ядро Xray", "zh": "Xray 内核", "es": "Núcleo Xray", "hi": "Xray कोर",
            "ar": "نواة Xray", "fr": "Noyau Xray", "pt": "Núcleo Xray", "de": "Xray-Kern",
            "ja": "Xray コア", "id": "Inti Xray", "tr": "Xray çekirdeği"],
        "geosite:/geoip: rules need these files.": [
            "ru": "Правила geosite:/geoip: требуют эти файлы.", "zh": "geosite:/geoip: 规则需要这些文件。", "es": "Las reglas geosite:/geoip: necesitan estos archivos.", "hi": "geosite:/geoip: नियमों के लिए ये फ़ाइलें ज़रूरी हैं।",
            "ar": "قواعد geosite:/geoip: تحتاج هذه الملفات.", "fr": "Les règles geosite:/geoip: nécessitent ces fichiers.", "pt": "As regras geosite:/geoip: precisam destes arquivos.", "de": "geosite:/geoip:-Regeln brauchen diese Dateien.",
            "ja": "geosite:/geoip: ルールにはこれらのファイルが必要です。", "id": "Aturan geosite:/geoip: memerlukan berkas ini.", "tr": "geosite:/geoip: kuralları bu dosyaları gerektirir."],
        "iOS asks you to allow the VPN configuration the first time you connect.": [
            "ru": "При первом подключении iOS попросит разрешить VPN-конфигурацию.", "zh": "首次连接时 iOS 会请求允许该 VPN 配置。", "es": "iOS te pedirá permitir la configuración VPN la primera vez que te conectes.", "hi": "पहली बार कनेक्ट करने पर iOS VPN कॉन्फ़िगरेशन की अनुमति माँगेगा।",
            "ar": "سيطلب منك iOS السماح بإعداد VPN عند أول اتصال.", "fr": "iOS vous demandera d'autoriser la configuration VPN à la première connexion.", "pt": "O iOS pedirá para permitir a configuração VPN na primeira conexão.", "de": "iOS fragt beim ersten Verbinden nach Erlaubnis für die VPN-Konfiguration.",
            "ja": "初回接続時に iOS が VPN 構成の許可を求めます。", "id": "iOS akan meminta izin konfigurasi VPN saat pertama kali terhubung.", "tr": "iOS ilk bağlantıda VPN yapılandırmasına izin vermenizi ister."],
        "needs sing-box": [
            "ru": "нужен sing-box", "zh": "需要 sing-box", "es": "requiere sing-box", "hi": "sing-box चाहिए",
            "ar": "يتطلب sing-box", "fr": "nécessite sing-box", "pt": "requer sing-box", "de": "braucht sing-box",
            "ja": "sing-box が必要", "id": "butuh sing-box", "tr": "sing-box gerekir"],
        "not supported on iOS": [
            "ru": "не поддерживается на iOS", "zh": "在 iOS 上不支持", "es": "no compatible con iOS", "hi": "iOS पर समर्थित नहीं",
            "ar": "غير مدعوم على iOS", "fr": "non pris en charge sur iOS", "pt": "sem suporte no iOS", "de": "unter iOS nicht unterstützt",
            "ja": "iOS では非対応", "id": "tidak didukung di iOS", "tr": "iOS'ta desteklenmiyor"],
        "timeout": [
            "ru": "таймаут", "zh": "超时", "es": "tiempo agotado", "hi": "टाइमआउट",
            "ar": "انتهت المهلة", "fr": "délai dépassé", "pt": "tempo esgotado", "de": "Zeitüberschreitung",
            "ja": "タイムアウト", "id": "waktu habis", "tr": "zaman aşımı"],

        // MARK: macOS settings
        "Launch at login": [
            "ru": "Запускать при входе", "zh": "登录时启动", "es": "Abrir al iniciar sesión", "hi": "लॉगिन पर लॉन्च करें",
            "ar": "التشغيل عند تسجيل الدخول", "fr": "Lancer à l'ouverture de session", "pt": "Abrir ao iniciar sessão", "de": "Beim Anmelden starten",
            "ja": "ログイン時に起動", "id": "Jalankan saat masuk", "tr": "Oturum açınca başlat"],
        "Notify on connect / disconnect": [
            "ru": "Уведомлять о подключении / отключении", "zh": "连接/断开时通知", "es": "Notificar al conectar / desconectar", "hi": "कनेक्ट / डिस्कनेक्ट पर सूचित करें",
            "ar": "تنبيه عند الاتصال / قطع الاتصال", "fr": "Notifier à la connexion / déconnexion", "pt": "Notificar ao conectar / desconectar", "de": "Bei Verbindung / Trennung benachrichtigen",
            "ja": "接続 / 切断時に通知", "id": "Beri tahu saat terhubung / terputus", "tr": "Bağlanınca / kesilince bildir"],
        "Edit": [
            "ru": "Изменить", "zh": "编辑", "es": "Editar", "hi": "संपादित करें",
            "ar": "تحرير", "fr": "Modifier", "pt": "Editar", "de": "Bearbeiten",
            "ja": "編集", "id": "Ubah", "tr": "Düzenle"],
        "Hold to connect": [
            "ru": "Удерживайте, чтобы подключить", "zh": "长按以连接", "es": "Mantén pulsado para conectar", "hi": "कनेक्ट करने के लिए दबाए रखें",
            "ar": "اضغط مطولًا للاتصال", "fr": "Maintenez pour connecter", "pt": "Mantenha pressionado para conectar", "de": "Zum Verbinden gedrückt halten",
            "ja": "長押しで接続", "id": "Tahan untuk menghubungkan", "tr": "Bağlanmak için basılı tutun"],
        "Hold to disconnect": [
            "ru": "Удерживайте, чтобы отключить", "zh": "长按以断开", "es": "Mantén pulsado para desconectar", "hi": "डिस्कनेक्ट करने के लिए दबाए रखें",
            "ar": "اضغط مطولًا لقطع الاتصال", "fr": "Maintenez pour déconnecter", "pt": "Mantenha pressionado para desconectar", "de": "Zum Trennen gedrückt halten",
            "ja": "長押しで切断", "id": "Tahan untuk memutuskan", "tr": "Bağlantıyı kesmek için basılı tutun"],
    ]
}
