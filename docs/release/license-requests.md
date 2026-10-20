# License requests (Noor): ready to send

Copied from the frozen Mushaf project and updated for **Noor** (ThawabForGod) on 2026-10-20. Send from your
own address; keep a copy of every reply in `docs/release/license-replies/` (a PDF or the e-mail text).

Facts that are the same in every message:
- App: **Noor**, a free Islamic app for iPhone, iPad and Mac: prayer times, Quran, hadith, adhkar. No ads, no
  in-app purchases, no accounts, no analytics. The Quran works fully offline: every Quran resource ships inside
  the app.
- The source code is public on GitHub (MIT), **but the resources asked about here are not in the public
  repository**; they are bundled only into the App Store build. The public build uses Tanzil's text instead.
- The Quran text, layout and fonts are shipped unchanged (checked by SHA-256 at build time).
- Every resource is credited by name in the app (Settings → Quran → Sources & licences) and, for translations
  and tafsir, under the text itself.
- Developer: Saad Sherif, Egypt, saadsherif02@gmail.com.

Not needed: Tanzil text (its terms allow it with credit and no changes), Tafsir al-Jalalayn (public domain),
KFGQPC HAFS Uthmanic Script font (its EULA allows free distribution), Amiri (OFL).

---

## Status

| # | To | Channel | Sent | Reply |
|---|---|---|---|---|
| 1 | QUL / Tarteel | GitHub issue (Blank issue), TarteelAI/quranic-universal-library | 2026-10-20, https://github.com/TarteelAI/quranic-universal-library/issues/907 | |
| 2 | King Fahd Quran Complex | e-mail to info@qurancomplex.gov.sa | 2026-10-20 | |
| 3 | Saheeh International | waiting for QUL's answer on the contact | | |
| 4 | Tafsir Center | e-mail to info@tafsir.net | 2026-10-20 | |
| 5 | Dar Al-Marifa, Freepik | only if QUL says no permission exists | | |

Follow up once after about 3 weeks without a reply.

---

## 1. QUL / Tarteel (rows 1–4, 6–11)

Where: a GitHub issue at https://github.com/TarteelAI/quranic-universal-library (or the QUL Discord).

### English

> **Subject:** Permission to bundle QUL resources in a free, offline Quran app
>
> Assalamu alaikum,
>
> I am building Noor, a free Islamic app for iPhone, iPad and Mac (prayer times, Quran, hadith, adhkar). Its
> Quran works fully offline, so it bundles its data instead of downloading it. The app's code is open source, but
> these resources would only be bundled in the App Store build, never published in the repository. I would like to ship these QUL resources, unchanged, with credit to QUL and the
> original publishers inside the app:
>
> - KFGQPC V2 layout (1421H print), resource mushaf-layout/10
> - KFGQPC Hafs script (word by word) and QPC V2 glyph codes (word by word)
> - QPC V2 page fonts (p1–p604)
> - Surah header font (QCF_SurahHeader_COLOR), surah name font v2, quran-common
> - Imlaei simple text (used only as a search index), Quran metadata, Surah information (English)
> - Translation 193 (Saheeh International) and the Tafsir al-Muyassar and Al-Mukhtasar (English) tafsirs
>
> Could you tell me, for each, whether redistribution inside a free app is allowed, what attribution you want,
> and whom else I must ask? In particular:
>
> 1. The surah header font's own metadata says "printing and publishing not permitted without prior permission
>    from King Fahad Glorious Quran Printing Complex and Dar Almarifa Easy Quran", and credits Freepik artwork.
>    Has permission been obtained for apps, or should I ask them directly?
> 2. The QPC V2 page fonts are named "Test Font, KFGQPC". Is there a released version or a license from KFGQPC?
> 3. Who wrote the English surah information, and what is its license?
> 4. The QUL resource ids for Tafsir al-Muyassar and Al-Mukhtasar (English), so I can cite them exactly.
>
> JazakumAllahu khairan for QUL.
> Saad Sherif — saadsherif02@gmail.com

### العربية

> **الموضوع:** طلب إذن بتضمين موارد QUL في تطبيق مصحف مجاني يعمل دون اتصال
>
> السلام عليكم ورحمة الله وبركاته،
>
> أعمل على تطبيق «نور» المجاني على iPhone وiPad وMac (مواقيت الصلاة والقرآن الكريم والحديث والأذكار). يعمل
> قسم القرآن دون اتصال بالإنترنت، لذلك يضمّ بياناته داخله بدلًا من تنزيلها. شيفرة التطبيق مفتوحة المصدر، لكن هذه
> الموارد لا تُضمَّن إلا في نسخة متجر التطبيقات ولا تُنشر في المستودع. أرغب في تضمين موارد QUL التالية دون أي تعديل، مع نسبتها إلى QUL وإلى
> الناشرين الأصليين داخل التطبيق:
>
> - تخطيط مصحف مجمع الملك فهد الإصدار الثاني (طبعة 1421هـ)، المورد mushaf-layout/10
> - نص حفص من المجمع (كلمة كلمة) ورموز خطوط QPC V2 (كلمة كلمة)
> - خطوط صفحات QPC V2 (من p1 إلى p604)
> - خط ترويسة السور (QCF_SurahHeader_COLOR) وخط أسماء السور v2 وخط quran-common
> - النص الإملائي المبسّط (للبحث فقط) وبيانات المصحف الوصفية ومعلومات السور (بالإنجليزية)
> - الترجمة رقم 193 (صحيح إنترناشيونال) والتفسير الميسر والمختصر في التفسير (بالإنجليزية)
>
> هل تتكرمون ببيان ما إذا كان إعادة توزيع كل منها داخل تطبيق مجاني مسموحًا، وصيغة النسبة المطلوبة، ومن يلزمني
> استئذانه غيركم؟ وعلى وجه الخصوص:
>
> 1. تذكر بيانات خط ترويسة السور أن «الطباعة والنشر غير مسموح بهما دون إذن مسبق من مجمع الملك فهد لطباعة
>    المصحف الشريف ودار المعرفة (Easy Quran)»، وتنسب بعض الزخارف إلى Freepik. هل حصلتم على إذن يشمل التطبيقات،
>    أم أتواصل معهم مباشرة؟
> 2. خطوط صفحات QPC V2 مسماة «Test Font, KFGQPC». هل يوجد إصدار نهائي أو ترخيص من المجمع؟
> 3. من مؤلف معلومات السور بالإنجليزية، وما ترخيصها؟
> 4. أرقام موارد التفسير الميسر والمختصر (بالإنجليزية) في QUL، لأذكرها بدقة.
>
> جزاكم الله خيرًا على هذه المكتبة.
> سعد شريف — saadsherif02@gmail.com

---

## 2. King Fahd Glorious Quran Printing Complex (rows 1–6, 13)

Where: https://qurancomplex.gov.sa → Contact Us (also the fonts site, fonts.qurancomplex.gov.sa). Arabic first.

### العربية

> **الموضوع:** طلب إذن باستخدام نص المصحف وخطوطه والتفسير الميسر في تطبيق مجاني
>
> السلام عليكم ورحمة الله وبركاته،
>
> أطوّر تطبيق «نور» المجاني على أجهزة Apple (iPhone وiPad وMac) لمواقيت الصلاة والقرآن الكريم والحديث والأذكار،
> بلا إعلانات ولا مشتريات، ويعمل قسم القرآن فيه دون اتصال بالإنترنت. يعرض التطبيق مصحف المدينة النبوية برواية حفص (طبعة 1421هـ) صفحةً صفحةً كما في
> المطبوع، ويعتمد على ما نشره المجمع، دون أي تعديل في النص أو الخطوط:
>
> 1. خطوط صفحات المصحف QPC V2 (604 ملفات، QCF2001–QCF2604) وتخطيط الصفحات والأسطر.
> 2. نص حفص بالرسم العثماني وخط «KFGQPC HAFS Uthmanic Script» الإصدار 2.2 (وقد اطلعت على اتفاقية الترخيص
>    المضمّنة فيه، وتسمح بالاستخدام والنسخ والتوزيع مجانًا).
> 3. خط ترويسة السور «QCF_SurahHeader_COLOR».
> 4. التفسير الميسر.
>
> حصلت على هذه الملفات من مكتبة القرآن الشاملة (QUL – qul.tarteel.ai). أرجو التكرم بالإذن بتضمينها في
> التطبيق، وبيان صيغة النسبة التي ترغبون فيها، علمًا بأن التطبيق ينسب كل مورد إلى المجمع داخل شاشة «حول
> التطبيق والمصادر». وألاحظ أن خطوط الصفحات مسماة «Test Font»؛ فإن كان لها إصدار نهائي أرجو إرشادي إليه.
>
> وجزاكم الله خيرًا على خدمة كتابه.
> سعد شريف — saadsherif02@gmail.com — مصر

### English

> **Subject:** Permission to use the Mushaf text, fonts and Tafsir al-Muyassar in a free app
>
> Assalamu alaikum,
>
> I am developing Noor, a free app for Apple devices (iPhone, iPad, Mac) with prayer times, Quran, hadith and
> adhkar, with no ads or purchases; its Quran works offline. It shows the Madinah Mushaf, Hafs, 1421H print, page by page as printed, using the Complex's
> work without any change to the text or the fonts:
>
> 1. The QPC V2 page fonts (604 files, QCF2001–QCF2604) and the page and line layout.
> 2. The Hafs Uthmani text and the "KFGQPC HAFS Uthmanic Script" font v2.2 (I have read its embedded license,
>    which allows free use, copying and distribution).
> 3. The surah header font "QCF_SurahHeader_COLOR".
> 4. Tafsir al-Muyassar.
>
> I obtained these through the Quranic Universal Library (qul.tarteel.ai). May I include them in the app, and how
> would you like them credited? The app credits the Complex for each in its About & Sources screen. The page fonts
> are named "Test Font"; if there is a final release, please point me to it.
>
> JazakumAllahu khairan.
> Saad Sherif — saadsherif02@gmail.com — Egypt

---

## 3. Saheeh International (row 12)

Where: the publisher of the printed edition (Dar Abul-Qasim / Abul-Qasim Publishing House, Saudi Arabia); the
address is on the copyright page of the print. Verify the current contact first.

### English

> **Subject:** Permission to include the Saheeh International translation in a free Quran app
>
> Assalamu alaikum,
>
> I am developing Noor, a free Islamic app for iPhone, iPad and Mac (no ads, no purchases, no accounts) whose
> Quran works entirely offline. I would like to include the Saheeh International English translation, with its footnotes,
> unchanged, shown under each ayah and credited as "Saheeh International" on every screen where it appears.
> The text comes from the Quranic Universal Library (qul.tarteel.ai, translation 193).
>
> May I include it? If so, what attribution or copyright line should the app show, and are there conditions
> (for example, keeping the app free)?
>
> JazakumAllahu khairan.
> Saad Sherif — saadsherif02@gmail.com — Egypt

### العربية

> **الموضوع:** طلب إذن بتضمين ترجمة صحيح إنترناشيونال في تطبيق مجاني للقرآن الكريم
>
> السلام عليكم ورحمة الله وبركاته،
>
> أطوّر تطبيق «نور» المجاني على iPhone وiPad وMac (بلا إعلانات ولا مشتريات ولا حسابات)، ويعمل قسم القرآن
> فيه دون اتصال بالإنترنت. أرغب في تضمين ترجمة صحيح إنترناشيونال الإنجليزية مع حواشيها دون تعديل، تُعرض تحت
> كل آية مع نسبتها إلى «صحيح إنترناشيونال» حيثما ظهرت. النص مأخوذ من مكتبة القرآن الشاملة (qul.tarteel.ai،
> الترجمة رقم 193).
>
> هل تأذنون بذلك؟ وما صيغة النسبة أو حقوق النشر التي ينبغي أن يعرضها التطبيق، وهل ثمة شروط (كأن يبقى التطبيق
> مجانيًا)؟
>
> جزاكم الله خيرًا.
> سعد شريف — saadsherif02@gmail.com — مصر

---

## 4. Tafsir Center for Quranic Studies (row 14)

Where: https://tafsir.net (contact page; verify). Arabic first.

### العربية

> **الموضوع:** طلب إذن بتضمين «المختصر في تفسير القرآن الكريم» (الترجمة الإنجليزية) في تطبيق مجاني
>
> السلام عليكم ورحمة الله وبركاته،
>
> أطوّر تطبيق «نور» المجاني على iPhone وiPad وMac، بلا إعلانات ولا مشتريات، ويعمل قسم القرآن فيه دون اتصال
> بالإنترنت. أرغب في تضمين الترجمة الإنجليزية للمختصر في التفسير (Abridged Explanation of the Quran) كما هي،
> تُعرض في لوحة الآية مع نسبتها إلى مركز تفسير للدراسات القرآنية. حصلت على النص من مكتبة القرآن الشاملة
> (qul.tarteel.ai).
>
> هل تأذنون بذلك؟ وما صيغة النسبة المطلوبة، وهل لديكم نسخة أحدث تفضّلون اعتمادها؟
>
> جزاكم الله خيرًا على هذا العمل.
> سعد شريف — saadsherif02@gmail.com — مصر

### English

> **Subject:** Permission to include Al-Mukhtasar (English) in a free Quran app
>
> Assalamu alaikum,
>
> I am developing Noor, a free Islamic app for iPhone, iPad and Mac, with no ads or purchases; its Quran works offline.
> I would like to include the English Abridged Explanation of the Quran (Al-Mukhtasar fi Tafsir al-Quran)
> unchanged, shown in the ayah panel and credited to the Tafsir Center for Quranic Studies. I obtained the text
> from the Quranic Universal Library (qul.tarteel.ai).
>
> May I include it? What attribution do you require, and is there a newer edition you would prefer me to use?
>
> JazakumAllahu khairan.
> Saad Sherif — saadsherif02@gmail.com — Egypt

---

## Also to ask (no draft yet)

- **Dar Al-Marifa (Easy Quran)**, named in the surah header font: same request as KFGQPC row 3, once QUL says
  whether permission already exists.
- **Freepik** (ornaments in the surah header font, by "pikisuperstar"): Freepik's free license needs attribution;
  the About screen gives it. A premium license removes that need.
