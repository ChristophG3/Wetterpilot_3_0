import XCTest
@testable import Wetterpilot_3_0

final class WeatherServiceTests: XCTestCase {
    func testDecodesOpenMeteoDailyForecast() throws {
        let json = """
        {
          "daily": {
            "time": ["2026-07-13"],
            "weather_code": [2],
            "temperature_2m_min": [18.4],
            "temperature_2m_max": [27.8],
            "apparent_temperature_min": [17.9],
            "apparent_temperature_max": [29.1],
            "precipitation_probability_max": [35],
            "precipitation_sum": [0.7],
            "wind_speed_10m_max": [21.5],
            "wind_gusts_10m_max": [38.2],
            "uv_index_max": [7.4],
            "sunrise": ["2026-07-13T06:28"],
            "sunset": ["2026-07-13T21:24"]
          }
        }
        """

        let result = try OpenMeteoWeatherService.decodeForecast(Data(json.utf8))

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].dateISO, "2026-07-13")
        XCTAssertEqual(result[0].weatherCode, 2)
        XCTAssertEqual(result[0].minimumTemperature, 18.4)
        XCTAssertEqual(result[0].maximumTemperature, 27.8)
        XCTAssertEqual(result[0].precipitationProbability, 35)
        XCTAssertEqual(result[0].precipitationAmount, 0.7)
        XCTAssertEqual(result[0].maximumWindSpeed, 21.5)
        XCTAssertEqual(result[0].minimumApparentTemperature, 17.9)
        XCTAssertEqual(result[0].maximumApparentTemperature, 29.1)
        XCTAssertEqual(result[0].maximumWindGust, 38.2)
        XCTAssertEqual(result[0].maximumUVIndex, 7.4)
        XCTAssertEqual(result[0].sunriseTime, "06:28")
        XCTAssertEqual(result[0].sunsetTime, "21:24")
    }

    func testKeepsCompleteDaysWhenLastForecastDayContainsNulls() throws {
        let json = """
        {
          "daily": {
            "time": ["2026-07-14", "2026-07-15"],
            "weather_code": [80, null],
            "temperature_2m_min": [26.6, null],
            "temperature_2m_max": [30.5, null],
            "precipitation_probability_max": [96, 34],
            "precipitation_sum": [6.6, null],
            "wind_speed_10m_max": [13.5, null]
          }
        }
        """

        let result = try OpenMeteoWeatherService.decodeForecast(Data(json.utf8))

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].dateISO, "2026-07-14")
        XCTAssertEqual(result[0].weatherCode, 80)
        XCTAssertEqual(result[0].precipitationProbability, 96)
    }

    func testRejectsForecastWhenEveryDayIsIncomplete() throws {
        let json = """
        {
          "daily": {
            "time": ["2026-07-14"],
            "weather_code": [null],
            "temperature_2m_min": [null],
            "temperature_2m_max": [null],
            "precipitation_probability_max": [null],
            "precipitation_sum": [null],
            "wind_speed_10m_max": [null]
          }
        }
        """

        XCTAssertThrowsError(try OpenMeteoWeatherService.decodeForecast(Data(json.utf8))) {
            guard case WeatherServiceError.malformedForecast = $0 else {
                return XCTFail("Expected malformedForecast, got \($0)")
            }
        }
    }
}
