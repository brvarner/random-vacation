require "sinatra"
require "sinatra/reloader"
require "date"
require "time"
require "http"
require "json"
require "factbook/codes"
require "factbook/readers"

get("/") do
  erb(:home)
end

post("/vacayresults") do
  @date = Date.new
  @unparsed_date = Date.new

  #We check the params to make sure the user entered a date. If they didn't, we redirect them to the nil date error page.
  if params["date"] != ""
    @date = Date.parse(params["date"])
    @unparsed_date = Time.new(params["date"]).to_i
  else
    redirect "/nil_date_error"
  end

  #First, we hit the REST Countries API for all of the standard information.
  if @date <= Date.today + 548 && @date >= Date.today
    country_res = HTTP.get("https://restcountries.com/v3.1/all?fields=name,flags,currencies,subregion,languages,latlng,ccn3")

    country_hash = JSON.parse(country_res)

    country = country_hash.sample

    @flag = country.dig("flags", "svg")
    @flag_alt = country.dig("flags", "alt")
    @country_official_name = country.dig("name", "official")
    @country_common_name = country.dig("name", "common")
    @country_lat = country.dig("latlng", 0)
    @country_lng = country.dig("latlng", 1)
    @currency = country.fetch("currencies").values

    #Next, we grab country information from the Factbook API
    codes = Factbook.codes
    lookup_code = Hash.new
    codes.each { |code| 
      if code.name == @country_common_name
        lookup_code = code
      end
    }

    if lookup_code
    final_code = lookup_code.code
    
    page = Factbook::Page.new(final_code)
    
    country_hash = page.to_h

    @country_location = country_hash['Geography']['Location']['text']
    @country_background = country_hash['Introduction']['Background']['text']

    #Next, we get the weather.
    weather_key = ENV["OPENWEATHER_KEY"]
    weather_res = HTTP.get("https://api.openweathermap.org/data/3.0/onecall/day_summary?lat=#{@country_lat}&lon=#{@country_lng}&units=imperial&date=#{@date}&appid=#{weather_key}")

    @parsed_weather_res = JSON.parse(weather_res)

    @temp_min = @parsed_weather_res.dig("temperature", "min")

    @temp_max = @parsed_weather_res.dig("temperature", "max")

    @precipitation = @parsed_weather_res.dig("precipitation", "total")

    #Lastly, we get the currency conversion.
    country_currency_code = country.fetch("currencies").first[0]
  
    conversion_api_url = "https://api.getgeoapi.com/v2/currency/convert
    ?api_key=#{ENV["EXCHANGE_KEY"]}&from=USD&to=#{country_currency_code}&amount=1&format=json"
    
  raw_conversion_data = HTTP.get(conversion_api_url)
  
  parsed_conversion_data = JSON.parse(raw_conversion_data)

  conversion_info = parsed_conversion_data.dig("rates", country_currency_code)

  @quote = conversion_info.fetch("rate").to_f.round(2)

    end
  else 
    redirect "/error"
  end

  erb(:vacayresults)
end

get("/error") do
  erb(:error)
end

get("/nil_date_error") do
  erb(:nil_date_error)
end
