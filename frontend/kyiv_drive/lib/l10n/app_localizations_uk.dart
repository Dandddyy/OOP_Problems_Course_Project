// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String greeting(Object name) {
    return 'Привіт, $name!';
  }

  @override
  String get welcomeTitle => 'Вітаємо!';

  @override
  String get loginButton => 'Увійти';

  @override
  String get passengerRole => 'Я пасажир';

  @override
  String get driverRole => 'Я водій';

  @override
  String get needToAuth => 'Для пошуку попутників\nнеобхідно авторизуватися';

  @override
  String get password => 'Пароль';

  @override
  String get confirmPassword => 'Підтвердьте пароль';

  @override
  String get noAccountYet => 'Ще немає акаунту? ';

  @override
  String get register => 'Зареєструватись';

  @override
  String get or => 'або';

  @override
  String get viaGoogle => 'Увійти за допомогою Google';

  @override
  String get completionRegister => 'Завершення реєстрації';

  @override
  String get chooseRoleDescription =>
      'Цей вибір визначає ваш основний функціонал.\nЗмінити роль можна будь-коли в налаштуваннях профілю.';

  @override
  String get yourName => 'Ваше ім\'я';

  @override
  String get confirmLogin => 'Підтвердити та увійти';

  @override
  String get cancel => 'Скасувати';

  @override
  String get leave => 'Вийти';

  @override
  String get waypointRedrawInProgressTitle => 'Вийти без збереження?';

  @override
  String get waypointRedrawInProgressMessage =>
      'Зараз триває перемальовування маршруту. Якщо вийти, зміни прапорців не збережуться.';

  @override
  String get unsavedChangesTitle => 'Незбережені зміни';

  @override
  String get unsavedChangesMessage =>
      'У вас є незбережені зміни. Зберегти їх перед виходом?';

  @override
  String get doNotSave => 'Не зберігати';

  @override
  String get waypointChangesNotRedrawnTitle => 'Маршрут не перемальовано';

  @override
  String get waypointChangesNotRedrawnMessage =>
      'Проміжні точки змінено, але маршрут ще не перемальовано. Перемалюйте його, щоб побачити оновлений шлях.';

  @override
  String get redraw => 'Перемалювати';

  @override
  String get registration => 'Реєстрація';

  @override
  String get alreadyHaveAccount => 'Вже є акаунт? ';

  @override
  String get login => 'Увійти';

  @override
  String get myRides => 'Мої поїздки';

  @override
  String get whereGoing => 'Куди їдемо?';

  @override
  String get savedTemplates => 'Збережені шаблони';

  @override
  String get findCompanion => 'Знайти попутника';

  @override
  String get letsGoLoading => 'Поїхали...';

  @override
  String get somethingWentWrong => 'Щось пішло не так. Спробуйте пізніше.';

  @override
  String get serviceBusy => 'Сервіс зайнятий';

  @override
  String get tryAgainLater => 'Спробуйте трохи пізніше.';

  @override
  String get retry => 'Повторити';

  @override
  String get requestTimedOut => 'Запит тривав надто довго. Спробуйте пізніше.';

  @override
  String get appUpdateRequiredTitle => 'Потрібне оновлення';

  @override
  String get appUpdateRequiredDescription =>
      'Ця версія KyivDrive більше не підтримується. Встановіть останню версію, щоб продовжити.';

  @override
  String get nameTooShort => 'Мінімум 2 символи';

  @override
  String get nameInvalidFormat => 'Некоректний формат імені';

  @override
  String get emailInvalidFormat => 'Некоректний формат email';

  @override
  String get passwordTooShort => 'Пароль занадто короткий';

  @override
  String get passwordComplexity => 'Потрібні велика, мала літери та цифра';

  @override
  String get passwordsDoNotMatch => 'Паролі не збігаються';

  @override
  String get forgotPassword => 'Забули пароль?';

  @override
  String get invalidCode => 'Неправильний код';

  @override
  String get profile => 'Профіль';

  @override
  String get unknownUser => 'Невідомий користувач';

  @override
  String get role => 'Роль';

  @override
  String get menu => 'Меню';

  @override
  String get cars => 'Автомобілі';

  @override
  String get privacy => 'Конфіденційність';

  @override
  String get help => 'Допомога';

  @override
  String get aboutService => 'Про сервіс';

  @override
  String get logoutFromProfile => 'Вийти з профілю';

  @override
  String get logout => 'Вийти';

  @override
  String get logoutTitle => 'Вийти з профілю?';

  @override
  String get logoutDescription =>
      'Ви впевнені, що хочете вийти з облікового запису? Для повторного входу потрібно буде ввести пароль.';

  @override
  String get reviewOne => 'відгук';

  @override
  String get reviewTwo => 'відгуки';

  @override
  String get reviewFive => 'відгуків';

  @override
  String get planingTrip => 'Планування поїздки';

  @override
  String get notRegular => 'Одноразова';

  @override
  String get regular => 'Регулярна';

  @override
  String get today => 'Сьогодні';

  @override
  String get tomorrow => 'Завтра';

  @override
  String get mon => 'Пн';

  @override
  String get tue => 'Вт';

  @override
  String get wed => 'Ср';

  @override
  String get thu => 'Чт';

  @override
  String get fri => 'Пт';

  @override
  String get sat => 'Сб';

  @override
  String get sun => 'Нд';

  @override
  String get monShort => 'Пн';

  @override
  String get tueShort => 'Вт';

  @override
  String get wedShort => 'Ср';

  @override
  String get thuShort => 'Чт';

  @override
  String get friShort => 'Пт';

  @override
  String get satShort => 'Сб';

  @override
  String get sunShort => 'Нд';

  @override
  String get emailConfirmationTitle => 'Підтвердження Email';

  @override
  String get recoveryTitle => 'Відновлення паролю';

  @override
  String get recoveryStep1Desc =>
      'Введіть email для отримання коду підтвердження';

  @override
  String recoveryStep2Desc(Object email) {
    return 'Введіть код, надісланий на $email';
  }

  @override
  String get recoveryStep3Desc => 'Створіть новий пароль';

  @override
  String get sendCode => 'Далі';

  @override
  String get verify => 'Перевірити';

  @override
  String get save => 'Зберегти';

  @override
  String get codeHint => 'Код';

  @override
  String get newPassword => 'Новий пароль';

  @override
  String get successResetPassword => 'Пароль успішно змінено';

  @override
  String get locationDisabledTitle => 'Геолокацію вимкнено';

  @override
  String get locationDisabledContent =>
      'Для зручної взаємодії з мапою необхідно увімкнути GPS.';

  @override
  String get enableButton => 'Увімкнути';

  @override
  String get locationPermissionDeniedTitle => 'Немає доступу до геолокації';

  @override
  String get locationPermissionDeniedContent =>
      'Додаток не може визначити ваше місцезнаходження. Дозвольте доступ у налаштуваннях.';

  @override
  String get settingsButton => 'Налаштування';

  @override
  String get allowLocationAccessToast => 'Дозвольте доступ до геопозиції';

  @override
  String get locationUnknownErrorToast =>
      'Не вдалося визначити місцезнаходження';

  @override
  String get outOfServiceArea => 'Ви знаходитесь поза зоною обслуговування';

  @override
  String get unknownLocation => 'Невідоме місце';

  @override
  String get route => 'Маршрут';

  @override
  String get where => 'Звідки';

  @override
  String get suggestedAddresses => 'Запропоновані адреси';

  @override
  String get refineSearchHint =>
      'Уточніть запит: додайте населений пункт або тип вулиці (вул., просп., бульв.)';

  @override
  String get done => 'Готово';

  @override
  String get selectOnMap => 'Обрати на мапі';

  @override
  String get selectTime => 'Оберіть час';

  @override
  String get jan => 'січня';

  @override
  String get feb => 'лютого';

  @override
  String get mar => 'березня';

  @override
  String get apr => 'квітня';

  @override
  String get may => 'травня';

  @override
  String get jun => 'червня';

  @override
  String get jul => 'липня';

  @override
  String get aug => 'серпня';

  @override
  String get sep => 'вересня';

  @override
  String get oct => 'жовтня';

  @override
  String get nov => 'листопада';

  @override
  String get dec => 'грудня';

  @override
  String get yearShort => 'р.';

  @override
  String get selectDifferentLocations =>
      'Будь ласка, оберіть різні локації для маршруту';

  @override
  String get rideDetails => 'Деталі поїздки';

  @override
  String get travelTime => 'Час у дорозі';

  @override
  String get distance => 'Відстань';

  @override
  String get routePreviewTotal => 'Загалом';

  @override
  String get minutesShort => 'хв';

  @override
  String get kilometersShort => 'км';

  @override
  String get hoursShort => 'год';

  @override
  String get metersShort => 'м';

  @override
  String get saveRoute => 'Зберегти маршрут';

  @override
  String get refreshRoute => 'Оновити маршрут';

  @override
  String get refreshRouteShort => 'Оновити';

  @override
  String get routeTemplateSaved => 'Збережено';

  @override
  String get routeSavedToTemplates => 'Маршрут збережено до шаблонів';

  @override
  String routeTooManyStops(int maximumStops) {
    return 'На маршруті забагато зупинок: максимум $maximumStops.';
  }

  @override
  String get selectDaysOfWeek => 'Оберіть дні тижня';

  @override
  String get selectFirstRideDateAndTime =>
      'Оберіть дату першої поїздки та час відправлення';

  @override
  String get selectDateAndTime => 'Оберіть дату та час відправлення';

  @override
  String get publishRide => 'Опублікувати поїздку';

  @override
  String get tripPublished => 'Поїздку опубліковано';

  @override
  String get publicationNonexistentTime =>
      'У цю дату годинник переводять уперед, тому вибраного часу не існує. Виберіть інший час.';

  @override
  String get publicationDepartureInPast =>
      'Час відправлення вже минув. Оберіть дату або час у майбутньому.';

  @override
  String get publicationDateNotSelectedWeekday =>
      'Дата першого відправлення має відповідати одному з обраних днів тижня.';

  @override
  String publicationDescriptionTooLong(int maximumLength) {
    return 'Опис не має перевищувати $maximumLength символів.';
  }

  @override
  String get publicationRefreshRouteRequired =>
      'Оновіть маршрут перед публікацією поїздки.';

  @override
  String get stops => 'Зупинки';

  @override
  String get select => 'Обрати';

  @override
  String get deleteTemplate => 'Видалити шаблон?';

  @override
  String get sureToDeleteTemplate =>
      'Ви впевнені, що хочете видалити цей маршрут?\nЦю дію не можна скасувати.';

  @override
  String get delete => 'Видалити';

  @override
  String get noSavedTemplates => 'Немає збережених шаблонів';

  @override
  String get routeWillAppear =>
      'Збережені маршрути з\'являться тут. Сплануйте подорож і натисніть на значок закладки, щоб зберегти його.';

  @override
  String get stop => 'Зупинка';

  @override
  String get markStops =>
      'Позначте зупинки, на яких вам буде зручно забирати або висаджувати попутників.';

  @override
  String get waypoints => 'Прапорці';

  @override
  String get waypoint => 'Прапорець';

  @override
  String get add => 'Додати';

  @override
  String get redrawRoute => 'Перемалювати маршрут';

  @override
  String get addWaypoint => 'Додати прапорець';

  @override
  String get addWaypointsToRedrawAndUpdate =>
      'Додайте прапорці, щоб змінити маршрут. Щоб оновити маршрут, натисніть \"Перемалювати маршрут\".';

  @override
  String get firstWaypointMatchesOrigin =>
      'Перший прапорець не може знаходитися в точці старту.';

  @override
  String get lastWaypointMatchesDestination =>
      'Останній прапорець не може знаходитися в точці фінішу.';

  @override
  String adjacentWaypointsMatch(
    Object firstWaypointNumber,
    Object secondWaypointNumber,
  ) {
    return 'Прапорці $firstWaypointNumber і $secondWaypointNumber не можуть знаходитися в одній точці.';
  }

  @override
  String deleteWaypoint(Object displayIndex) {
    return 'Видалити прапорець $displayIndex?';
  }

  @override
  String sureToDeleteWaypoint(Object displayIndex) {
    return 'Ви впевнені, що хочете видалити прапорець $displayIndex з маршруту?';
  }

  @override
  String get makeSureTheRouteSuitsYou =>
      'Переконайтеся, що маршрут вам підходить. Лінію шляху та активні зупинки можна змінити.';

  @override
  String get serverTimeout =>
      'Сервер не відповідає. Будь ласка, перевірте підключення до інтернету.';

  @override
  String get noInternetConnection =>
      'Йой, інтернет кудись зник. Будь ласка, перевірте підключення.';

  @override
  String get noStopsFound => 'Зупинок не знайдено';

  @override
  String get noStopsDescription =>
      'На цьому маршруті відсутні зупинки громадського транспорту';

  @override
  String get colorWhite => 'Білий';

  @override
  String get colorBlack => 'Чорний';

  @override
  String get colorGray => 'Сірий';

  @override
  String get colorSilver => 'Сріблястий';

  @override
  String get colorRed => 'Червоний';

  @override
  String get colorBlue => 'Синій';

  @override
  String get colorGreen => 'Зелений';

  @override
  String get colorBrown => 'Коричневий';

  @override
  String get colorBeige => 'Бежевий';

  @override
  String get colorYellow => 'Жовтий';

  @override
  String get colorOrange => 'Помаранчевий';

  @override
  String get colorPurple => 'Фіолетовий';

  @override
  String get deleteCar => 'Видалити автомобіль?';

  @override
  String sureToDeleteCar(Object brand, Object model) {
    return 'Ви впевнені, що хочете видалити $brand $model?\nЦю дію не можна скасувати.';
  }

  @override
  String get scheduleRide => 'Розклад поїздки';

  @override
  String get chooseCar => 'Оберіть автомобіль';

  @override
  String get specifyFixedOrPerKilometerPrice =>
      'Вкажіть фіксовану ціну або ціну за 1 км';

  @override
  String get price => 'Ціна';

  @override
  String get fixedPrice => 'Фіксована ціна';

  @override
  String get pricePerKilometer => 'Ціна за 1 км';

  @override
  String get allowPriceNegotiation => 'Дозволити торг';

  @override
  String get priceNegotiationHint => 'Пасажири зможуть пропонувати свою ціну';

  @override
  String get describeRideDetails =>
      'Опишіть деталі поїздки, які буде корисно знати потенційним пасажирам (необов’язково)';

  @override
  String get rideDescriptionHint =>
      'Наприклад: «У поїздці грає музика», «Можна курити електронні сигарети»';

  @override
  String get carWithThisNumber => 'Авто з таким номером вже додано';

  @override
  String get standardNumberNeedToEnterLatin =>
      'Стандартний номер потрібно вводити латиницею';

  @override
  String get incorrectNumberFormat => 'Невірний формат номера';

  @override
  String get numberAndSeatClue =>
      'Номер бачитимуть лише підтверджені на поїздку пасажири.\nМісця — скільки пасажирів ви готові взяти.';

  @override
  String get addCar => 'Додати автомобіль';

  @override
  String get editCar => 'Редагувати автомобіль';

  @override
  String get carEditExistingTripsHint =>
      'Зміни не вплинуть на дані автомобіля у вже створених поїздках.';

  @override
  String get brand => 'Марка';

  @override
  String get model => 'Модель';

  @override
  String get number => 'Номер';

  @override
  String get seats => 'Місця';

  @override
  String get bodyColor => 'Колір кузова';

  @override
  String get anotherCar => 'Інший автомобіль';

  @override
  String get nothingFound => 'Нічого не знайдено';

  @override
  String get seatOne => 'місце';

  @override
  String get seatTwo => 'місця';

  @override
  String get seatFive => 'місць';

  @override
  String get searchPriorities => 'Пріоритети пошуку';

  @override
  String get searchTimePreferencesHint =>
      'Будь ласка, вкажіть бажаний час відправлення та прибуття. Ми врахуємо ваші побажання навіть без обраного пріоритету.';

  @override
  String get chooseMainSearchPriority => 'Оберіть головний пріоритет';

  @override
  String get rankSearchPriorities => 'Розташуйте пріоритети за важливістю';

  @override
  String get noSearchPriority => 'Без пріоритету';

  @override
  String get balancedSearchDescription => 'Усі критерії рівнозначні';

  @override
  String get priorityDeparture => 'Почати після';

  @override
  String get priorityArrival => 'Прибути не пізніше';

  @override
  String get priorityWalking => 'Менше йти пішки';

  @override
  String get priorityPrice => 'Менша вартість';

  @override
  String get priorityWeekdays => 'Збіг днів тижня';

  @override
  String get orderSearchPriorities => 'Встановити порядок пріоритетів';

  @override
  String get resetSearchPriorities => 'Скинути порядок пріоритетів';

  @override
  String priorityArrivalDayOffset(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Через $days дн.',
      one: 'Наступного дня',
    );
    return '$_temp0';
  }

  @override
  String get movePriorityUp => 'Перемістити пріоритет вище';

  @override
  String get movePriorityDown => 'Перемістити пріоритет нижче';

  @override
  String get routes => 'Маршрути';

  @override
  String get tripSearchSort => 'Сортування';

  @override
  String get tripSearchFilter => 'Фільтр';

  @override
  String get tripSearchTimeFits =>
      'Відправлення та прибуття вкладаються в бажаний час';

  @override
  String get tripSearchTimeMismatch =>
      'Відправлення раніше або прибуття пізніше бажаного часу';

  @override
  String get tripSearchScheduleFits => 'Збігаються всі запитані дати';

  @override
  String get tripSearchScheduleIncomplete =>
      'Підходять лише деякі запитані дати';

  @override
  String get tripSearchScheduleStartsLater =>
      'Перша поїздка починається пізніше бажаної дати';

  @override
  String get tripSearchIdentityVerificationUnavailable =>
      'Підтвердження особи через Дію поки недоступне';

  @override
  String get tripSearchNoReviews => 'Ще немає відгуків';

  @override
  String tripSearchFirstTripOn(String date) {
    return 'Перша поїздка — $date';
  }

  @override
  String tripSearchAvailableSeats(int available, int total) {
    return 'Вільних пасажирських місць: $available із $total';
  }

  @override
  String tripSearchDayOffset(int days) {
    return '+$days дн.';
  }

  @override
  String get tripSearchByCar => 'Автомобілем';

  @override
  String get tripSearchEmpty => 'Маршрутів не знайдено';

  @override
  String get tripSearchEmptyHint =>
      'Спробуйте змінити дату, час або маршрут в умовах пошуку.';

  @override
  String get tripSearchBusy => 'Сервіс пошуку зайнятий';

  @override
  String get tripSearchRateLimited => 'Забагато запитів';

  @override
  String get tripSearchLoadMoreFailed =>
      'Не вдалося завантажити більше маршрутів';

  @override
  String get tripSearchRefresh => 'Оновити пошук';

  @override
  String get tripSearchExpired => 'Результати пошуку застаріли';
}
