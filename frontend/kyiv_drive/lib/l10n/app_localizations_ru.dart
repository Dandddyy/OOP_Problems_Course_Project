// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String greeting(Object name) {
    return 'Привет, $name!';
  }

  @override
  String get welcomeTitle => 'Приветствуем!';

  @override
  String get loginButton => 'Войти';

  @override
  String get passengerRole => 'Я пассажир';

  @override
  String get driverRole => 'Я водитель';

  @override
  String get needToAuth => 'Для поиска попутчиков\nнеобходимо авторизоваться';

  @override
  String get password => 'Пароль';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get noAccountYet => 'Еще нет аккаунта? ';

  @override
  String get register => 'Зарегистрироваться';

  @override
  String get or => 'или';

  @override
  String get viaGoogle => 'Войти с помощью Google';

  @override
  String get completionRegister => 'Завершение регистрации';

  @override
  String get chooseRoleDescription =>
      'Этот выбор определяет ваш основной функционал.\nИзменить роль можно в любой момент в настройках профиля.';

  @override
  String get yourName => 'Ваше имя';

  @override
  String get confirmLogin => 'Подтвердить и войти';

  @override
  String get cancel => 'Отмена';

  @override
  String get leave => 'Выйти';

  @override
  String get waypointRedrawInProgressTitle => 'Выйти без сохранения?';

  @override
  String get waypointRedrawInProgressMessage =>
      'Сейчас идёт перерисовка маршрута. Если выйти, изменения флажков не сохранятся.';

  @override
  String get unsavedChangesTitle => 'Несохранённые изменения';

  @override
  String get unsavedChangesMessage =>
      'У вас есть несохранённые изменения. Сохранить их перед выходом?';

  @override
  String get doNotSave => 'Не сохранять';

  @override
  String get waypointChangesNotRedrawnTitle => 'Маршрут не перерисован';

  @override
  String get waypointChangesNotRedrawnMessage =>
      'Промежуточные точки изменены, но маршрут ещё не перерисован. Перерисуйте его, чтобы увидеть обновлённый путь.';

  @override
  String get redraw => 'Перерисовать';

  @override
  String get registration => 'Регистрация';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт? ';

  @override
  String get login => 'Войти';

  @override
  String get myRides => 'Мои поездки';

  @override
  String get whereGoing => 'Куда едем?';

  @override
  String get savedTemplates => 'Сохраненные шаблоны';

  @override
  String get findCompanion => 'Найти попутчика';

  @override
  String get letsGoLoading => 'Поехали...';

  @override
  String get somethingWentWrong => 'Что-то пошло не так. Попробуйте позже.';

  @override
  String get serviceBusy => 'Сервис занят';

  @override
  String get tryAgainLater => 'Попробуйте чуть позже.';

  @override
  String get retry => 'Повторить';

  @override
  String get requestTimedOut =>
      'Запрос занял слишком много времени. Попробуйте позже.';

  @override
  String get appUpdateRequiredTitle => 'Требуется обновление';

  @override
  String get appUpdateRequiredDescription =>
      'Эта версия KyivDrive больше не поддерживается. Установите последнюю версию, чтобы продолжить.';

  @override
  String get nameTooShort => 'Минимум 2 символа';

  @override
  String get nameInvalidFormat => 'Неверный формат имени';

  @override
  String get emailInvalidFormat => 'Некорректный формат email';

  @override
  String get passwordTooShort => 'Слишком короткий пароль';

  @override
  String get passwordComplexity => 'Нужна заглавная буква, строчная и цифра';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get invalidCode => 'Неверный код';

  @override
  String get profile => 'Профиль';

  @override
  String get unknownUser => 'Неизвестный пользователь';

  @override
  String get role => 'Роль';

  @override
  String get menu => 'Меню';

  @override
  String get cars => 'Автомобили';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get help => 'Помощь';

  @override
  String get aboutService => 'О сервисе';

  @override
  String get logoutFromProfile => 'Выйти из профиля';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutTitle => 'Выйти из профиля?';

  @override
  String get logoutDescription =>
      'Вы уверены, что хотите выйти из учётной записи? Для повторного входа потребуется ввести пароль.';

  @override
  String get reviewOne => 'отзыв';

  @override
  String get reviewTwo => 'отзыва';

  @override
  String get reviewFive => 'отзывов';

  @override
  String get planingTrip => 'Планирование поездки';

  @override
  String get notRegular => 'Одноразовая';

  @override
  String get regular => 'Регулярная';

  @override
  String get today => 'Сегодня';

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
  String get sun => 'Вс';

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
  String get sunShort => 'Вс';

  @override
  String get emailConfirmationTitle => 'Подтверждение Email';

  @override
  String get recoveryTitle => 'Восстановление пароля';

  @override
  String get recoveryStep1Desc =>
      'Введите email для получения кода подтверждения';

  @override
  String recoveryStep2Desc(Object email) {
    return 'Введите код, отправленный на $email';
  }

  @override
  String get recoveryStep3Desc => 'Придумайте новый пароль';

  @override
  String get sendCode => 'Далее';

  @override
  String get verify => 'Проверить';

  @override
  String get save => 'Сохранить';

  @override
  String get codeHint => 'Код';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get successResetPassword => 'Пароль успешно изменён';

  @override
  String get locationDisabledTitle => 'Геолокация выключена';

  @override
  String get locationDisabledContent =>
      'Для удобного взаимодействия с картой необходимо включить GPS.';

  @override
  String get enableButton => 'Включить';

  @override
  String get locationPermissionDeniedTitle => 'Нет доступа к геолокации';

  @override
  String get locationPermissionDeniedContent =>
      'Приложение не может определить ваше местоположение. Разрешите доступ в настройках.';

  @override
  String get settingsButton => 'Настройки';

  @override
  String get allowLocationAccessToast => 'Разрешите доступ к геопозиции';

  @override
  String get locationUnknownErrorToast =>
      'Не удалось определить местоположение';

  @override
  String get outOfServiceArea => 'Вы находитесь вне зоны обслуживания';

  @override
  String get unknownLocation => 'Неизвестное место';

  @override
  String get route => 'Маршрут';

  @override
  String get where => 'Откуда';

  @override
  String get suggestedAddresses => 'Предложенные адреса';

  @override
  String get refineSearchHint =>
      'Уточните запрос: добавьте населенный пункт или тип улицы (ул., просп., бульв.)';

  @override
  String get done => 'Готово';

  @override
  String get selectOnMap => 'Выбрать на карте';

  @override
  String get selectTime => 'Выберите время';

  @override
  String get jan => 'января';

  @override
  String get feb => 'февраля';

  @override
  String get mar => 'марта';

  @override
  String get apr => 'апреля';

  @override
  String get may => 'мая';

  @override
  String get jun => 'июня';

  @override
  String get jul => 'июля';

  @override
  String get aug => 'августа';

  @override
  String get sep => 'сентября';

  @override
  String get oct => 'октября';

  @override
  String get nov => 'ноября';

  @override
  String get dec => 'декабря';

  @override
  String get yearShort => 'г.';

  @override
  String get selectDifferentLocations =>
      'Пожалуйста, выберите разные локации для маршрута';

  @override
  String get rideDetails => 'Детали поездки';

  @override
  String get travelTime => 'Время в пути';

  @override
  String get distance => 'Расстояние';

  @override
  String get routePreviewTotal => 'Всего';

  @override
  String get minutesShort => 'мин';

  @override
  String get kilometersShort => 'км';

  @override
  String get hoursShort => 'ч';

  @override
  String get metersShort => 'м';

  @override
  String get saveRoute => 'Сохранить маршрут';

  @override
  String get refreshRoute => 'Обновить маршрут';

  @override
  String get refreshRouteShort => 'Обновить';

  @override
  String get routeTemplateSaved => 'Сохранено';

  @override
  String get routeSavedToTemplates => 'Маршрут сохранен в шаблоны';

  @override
  String routeTooManyStops(int maximumStops) {
    return 'На маршруте слишком много остановок: максимум $maximumStops.';
  }

  @override
  String get selectDaysOfWeek => 'Выберите дни недели';

  @override
  String get selectFirstRideDateAndTime =>
      'Выберите дату первой поездки и время отправления';

  @override
  String get selectDateAndTime => 'Выберите дату и время отправления';

  @override
  String get publishRide => 'Опубликовать поездку';

  @override
  String get tripPublished => 'Поездка опубликована';

  @override
  String get publicationNonexistentTime =>
      'В эту дату часы переводят вперёд, поэтому выбранного времени не существует. Выберите другое время.';

  @override
  String get publicationDepartureInPast =>
      'Время отправления уже прошло. Выберите дату или время в будущем.';

  @override
  String get publicationDateNotSelectedWeekday =>
      'Дата первого отправления должна соответствовать одному из выбранных дней недели.';

  @override
  String publicationDescriptionTooLong(int maximumLength) {
    return 'Описание не должно превышать $maximumLength символов.';
  }

  @override
  String get publicationRefreshRouteRequired =>
      'Обновите маршрут перед публикацией поездки.';

  @override
  String get stops => 'Остановки';

  @override
  String get select => 'Выбрать';

  @override
  String get deleteTemplate => 'Удалить шаблон?';

  @override
  String get sureToDeleteTemplate =>
      'Вы уверены, что хотите удалить этот маршрут?\nЭто действие нельзя отменить.';

  @override
  String get delete => 'Удалить';

  @override
  String get noSavedTemplates => 'Нет сохраненных шаблонов';

  @override
  String get routeWillAppear =>
      'Сохраненные маршруты появятся здесь. Спланируйте поездку и нажмите на значок закладки, чтобы сохранить её.';

  @override
  String get stop => 'Остановка';

  @override
  String get markStops =>
      'Отметьте остановки, на которых вам будет удобно забирать или высаживать попутчиков.';

  @override
  String get waypoints => 'Флажки';

  @override
  String get waypoint => 'Флажок';

  @override
  String get add => 'Добавить';

  @override
  String get redrawRoute => 'Перерисовать маршрут';

  @override
  String get addWaypoint => 'Добавить флажок';

  @override
  String get addWaypointsToRedrawAndUpdate =>
      'Добавьте флажки, чтобы изменить маршрут. Чтобы обновить маршрут нажмите \"Перерисовать маршрут\".';

  @override
  String get firstWaypointMatchesOrigin =>
      'Первый флажок не может находиться в точке старта.';

  @override
  String get lastWaypointMatchesDestination =>
      'Последний флажок не может находиться в точке финиша.';

  @override
  String adjacentWaypointsMatch(
    Object firstWaypointNumber,
    Object secondWaypointNumber,
  ) {
    return 'Флажки $firstWaypointNumber и $secondWaypointNumber не могут находиться в одной точке.';
  }

  @override
  String deleteWaypoint(Object displayIndex) {
    return 'Удалить флажок $displayIndex?';
  }

  @override
  String sureToDeleteWaypoint(Object displayIndex) {
    return 'Вы уверены, что хотите удалить флажок $displayIndex из маршрута?';
  }

  @override
  String get makeSureTheRouteSuitsYou =>
      'Убедитесь, что маршрут вам подходит. Линию пути и активные остановки можно изменить.';

  @override
  String get serverTimeout =>
      'Сервер не отвечает. Пожалуйста, проверьте подключение к интернету.';

  @override
  String get noInternetConnection =>
      'Упс, интернет куда-то пропал. Пожалуйста, проверьте подключение.';

  @override
  String get noStopsFound => 'Остановок не найдено';

  @override
  String get noStopsDescription =>
      'На данном маршруте отсутствуют остановки общественного транспорта';

  @override
  String get colorWhite => 'Белый';

  @override
  String get colorBlack => 'Чёрный';

  @override
  String get colorGray => 'Серый';

  @override
  String get colorSilver => 'Серебристый';

  @override
  String get colorRed => 'Красный';

  @override
  String get colorBlue => 'Синий';

  @override
  String get colorGreen => 'Зелёный';

  @override
  String get colorBrown => 'Коричневый';

  @override
  String get colorBeige => 'Бежевый';

  @override
  String get colorYellow => 'Жёлтый';

  @override
  String get colorOrange => 'Оранжевый';

  @override
  String get colorPurple => 'Фиолетовый';

  @override
  String get deleteCar => 'Удалить автомобиль?';

  @override
  String sureToDeleteCar(Object brand, Object model) {
    return 'Вы уверены, что хотите удалить $brand $model?\nЭто действие нельзя отменить.';
  }

  @override
  String get scheduleRide => 'Расписание поездки';

  @override
  String get chooseCar => 'Выберите автомобиль';

  @override
  String get specifyFixedOrPerKilometerPrice =>
      'Укажите фиксированную цену или цену за 1 км';

  @override
  String get price => 'Цена';

  @override
  String get fixedPrice => 'Фиксированная цена';

  @override
  String get pricePerKilometer => 'Цена за 1 км';

  @override
  String get allowPriceNegotiation => 'Разрешить торг';

  @override
  String get priceNegotiationHint => 'Пассажиры смогут предложить свою цену';

  @override
  String get describeRideDetails =>
      'Опишите детали поездки, которые будет полезно знать потенциальным пассажирам (необязательно)';

  @override
  String get rideDescriptionHint =>
      'Например: «В поездке играет музыка», «Можно курить электронные сигареты»';

  @override
  String get carWithThisNumber => 'Авто с таким номером уже добавлено';

  @override
  String get standardNumberNeedToEnterLatin =>
      'Стандартный номер нужно вводить латиницей';

  @override
  String get incorrectNumberFormat => 'Неверный формат номера';

  @override
  String get numberAndSeatClue =>
      'Номер будут видеть только подтвержденные на поездку пассажиры.\nМеста — сколько пассажиров вы готовы взять.';

  @override
  String get addCar => 'Добавить автомобиль';

  @override
  String get editCar => 'Редактировать автомобиль';

  @override
  String get carEditExistingTripsHint =>
      'Изменения не повлияют на данные автомобиля в уже созданных поездках.';

  @override
  String get brand => 'Марка';

  @override
  String get model => 'Модель';

  @override
  String get number => 'Номер';

  @override
  String get seats => 'Места';

  @override
  String get bodyColor => 'Цвет кузова';

  @override
  String get anotherCar => 'Другой автомобиль';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get seatOne => 'место';

  @override
  String get seatTwo => 'места';

  @override
  String get seatFive => 'мест';

  @override
  String get searchPriorities => 'Приоритеты поиска';

  @override
  String get searchTimePreferencesHint =>
      'Пожалуйста, укажите желаемое время отправления и прибытия. Мы учтём ваши пожелания даже без выбранного приоритета.';

  @override
  String get chooseMainSearchPriority => 'Выберите главный приоритет';

  @override
  String get rankSearchPriorities => 'Расположите приоритеты по важности';

  @override
  String get noSearchPriority => 'Без приоритета';

  @override
  String get balancedSearchDescription => 'Все критерии равнозначны';

  @override
  String get priorityDeparture => 'Начать после';

  @override
  String get priorityArrival => 'Прибыть не позже';

  @override
  String get priorityWalking => 'Меньше идти пешком';

  @override
  String get priorityPrice => 'Меньшая стоимость';

  @override
  String get priorityWeekdays => 'Совпадение дней недели';

  @override
  String get orderSearchPriorities => 'Выставить порядок приоритетов';

  @override
  String get resetSearchPriorities => 'Сбросить порядок';

  @override
  String priorityArrivalDayOffset(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Через $days дн.',
      one: 'На следующий день',
    );
    return '$_temp0';
  }

  @override
  String get movePriorityUp => 'Переместить приоритет выше';

  @override
  String get movePriorityDown => 'Переместить приоритет ниже';

  @override
  String get routes => 'Маршруты';

  @override
  String get tripSearchSort => 'Сортировка';

  @override
  String get tripSearchFilter => 'Фильтр';

  @override
  String get tripSearchTimeFits =>
      'Отправление и прибытие укладываются в желаемое время';

  @override
  String get tripSearchTimeMismatch =>
      'Отправление раньше или прибытие позже желаемого времени';

  @override
  String get tripSearchScheduleFits => 'Совпадают все запрошенные даты';

  @override
  String get tripSearchScheduleIncomplete =>
      'Подходят только некоторые запрошенные даты';

  @override
  String get tripSearchScheduleStartsLater =>
      'Первая поездка начинается позже желаемой даты';

  @override
  String get tripSearchIdentityVerificationUnavailable =>
      'Подтверждение личности через «Дію» пока недоступно';

  @override
  String get tripSearchNoReviews => 'Пока нет отзывов';

  @override
  String tripSearchFirstTripOn(String date) {
    return 'Первая поездка — $date';
  }

  @override
  String tripSearchAvailableSeats(int available, int total) {
    return 'Свободных пассажирских мест: $available из $total';
  }

  @override
  String tripSearchDayOffset(int days) {
    return '+$days дн.';
  }

  @override
  String get tripSearchByCar => 'На автомобиле';

  @override
  String get tripSearchEmpty => 'Маршруты не найдены';

  @override
  String get tripSearchEmptyHint =>
      'Попробуйте изменить дату, время или маршрут в условиях поиска.';

  @override
  String get tripSearchBusy => 'Сервис поиска занят';

  @override
  String get tripSearchRateLimited => 'Слишком много запросов';

  @override
  String get tripSearchLoadMoreFailed => 'Не удалось загрузить ещё маршруты';

  @override
  String get tripSearchRefresh => 'Обновить поиск';

  @override
  String get tripSearchExpired => 'Результаты поиска устарели';
}
