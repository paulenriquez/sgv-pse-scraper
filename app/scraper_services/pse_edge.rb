class PseEdge < ScraperService
    SCRAPER_SERVICE = { name: 'PseEdge', version: '1.0' }
    
    def initialize(launched_from = nil)
        initialize_scraper_service(SCRAPER_SERVICE, launched_from)
    end
    
    private
        def main
            scrape_market_status
            scrape_indices
            scrape_stocks
        end
        def scrape_market_status
            urls = {
                 market_status: 'http://edge.pse.com.ph/index/form.do'
            }
            market_status_page = Nokogiri::HTML(HTTParty.get(urls[:market_status]))
            
            data_market_status = DataMarketStatus.new(scraper_session_id: @current_session.id)
            
            update_status("Scraping Market Status from #{urls[:market_status]}")
            
            data_market_status.last_updated  = market_status_page.css('div#market table.list:eq(1) thead tr th:eq(2)').text
            data_market_status.total_volume  = market_status_page.css('div#market table.list:eq(1) tbody tr:eq(1) td:eq(2)').text
            data_market_status.total_trades  = market_status_page.css('div#market table.list:eq(1) tbody tr:eq(2) td:eq(2)').text
            data_market_status.total_value   = market_status_page.css('div#market table.list:eq(1) tbody tr:eq(3) td:eq(2)').text
            data_market_status.advances      = market_status_page.css('div#market table.list:eq(1) tbody tr:eq(4) td:eq(2)').text
            data_market_status.declines      = market_status_page.css('div#market table.list:eq(1) tbody tr:eq(5) td:eq(2)').text
            data_market_status.unchanged     = market_status_page.css('div#market table.list:eq(1) tbody tr:eq(6) td:eq(2)').text
        
            data_market_status.save
        end
        def scrape_indices
            urls = {
                indices: 'http://edge.pse.com.ph/index/form.do'
            }
            
            index_data_page = Nokogiri::HTML(HTTParty.get(urls[:indices]))
            
            update_status("Scraping Index Data from #{urls[:indices]}")
            index_data_page.css('div#index table.list:eq(1) tbody tr').each do |table_row|
                update_status("Scraping Index Data from #{urls[:indices]} — #{table_row.css('td.label').text} ...")
                
                data_index = DataIndex.new(scraper_session_id: @current_session.id)
                
                data_index.index           = table_row.css('td.label').text
                data_index.value           = table_row.css('td:eq(2)').text
                data_index.change          = table_row.css('td:eq(3)').text
                data_index.percent_change  = table_row.css('td:eq(4)').text
                
                data_index.save
            end
        end
        def scrape_stocks
            urls = {
                company_list: 'http://edge.pse.com.ph/companyDirectory/search.ax#company',
                stock_data: 'http://edge.pse.com.ph/companyPage/stockData.do',
                stock_company_info: 'http://edge.pse.com.ph/companyInformation/form.do'
            }
            
            company_list_page = Nokogiri::HTML(HTTParty.get(urls[:company_list]))
            
            for page_num in 1..company_list_page.css('div.paging span').count
                company_list_page = Nokogiri::HTML(
                    HTTParty.post(urls[:company_list], body: {pageNo: page_num})
                ) if page_num != 1
                
                company_list_page.css('table.list tbody tr td:eq(1) a').each do |link|
                    company_id = link.attr('onclick').split(';').shift[0..-2].split('(').pop.split(',').shift[1..-2]
                    
                    stock_data_page = Nokogiri::HTML(HTTParty.get(urls[:stock_data] + "?cmpy_id=#{company_id}"))
                    company_info_page = Nokogiri::HTML(HTTParty.get(urls[:stock_company_info] + "?cmpy_id=#{company_id}"))
                    
                    stock_data_page.css('div#contents form select[name=security_id] option').each do |option|
                        security_id = option.attr('value')
                        stock_data_page = Nokogiri::HTML(HTTParty.get(urls[:stock_data] + "?cmpy_id=#{company_id}&security_id=#{security_id}"))
                        
                        data_stock = DataStock.new(scraper_session_id: @current_session.id)
                        
                        update_status("Scraping Stock Data from #{urls[:stock_data] + "?cmpy_id=#{company_id}&security_id=#{security_id}"} — #{stock_data_page.css('div#contents form select[name=security_id] option[selected]').text}")
                        
                        data_stock.ticker                      = stock_data_page.css('div#contents form select[name=security_id] option[selected]').text
                        data_stock.last_updated                = stock_data_page.css('div#contents form span:eq(1)').text
                        data_stock.status                      = stock_data_page.css('div#contents table.view:eq(1) tr:eq(1) td:eq(1)').text
                        data_stock.issue_type                  = stock_data_page.css('div#contents table.view:eq(1) tr:eq(2) td:eq(1)').text
                        data_stock.isin                        = stock_data_page.css('div#contents table.view:eq(1) tr:eq(3) td:eq(1)').text
                        data_stock.listing_date                = stock_data_page.css('div#contents table.view:eq(1) tr:eq(4) td:eq(1)').text
                        data_stock.board_lot                   = stock_data_page.css('div#contents table.view:eq(1) tr:eq(5) td:eq(1)').text
                        data_stock.par_value                   = stock_data_page.css('div#contents table.view:eq(1) tr:eq(6) td:eq(1)').text
                        data_stock.market_capitalization       = stock_data_page.css('div#contents table.view:eq(1) tr:eq(1) td:eq(2)').text
                        data_stock.outstanding_shares          = stock_data_page.css('div#contents table.view:eq(1) tr:eq(2) td:eq(2)').text
                        data_stock.listed_shares               = stock_data_page.css('div#contents table.view:eq(1) tr:eq(3) td:eq(2)').text
                        data_stock.issued_shares               = stock_data_page.css('div#contents table.view:eq(1) tr:eq(4) td:eq(2)').text
                        data_stock.free_float_level            = stock_data_page.css('div#contents table.view:eq(1) tr:eq(5) td:eq(2)').text
                        data_stock.foreign_ownership_limit     = stock_data_page.css('div#contents table.view:eq(1) tr:eq(6) td:eq(2)').text
                        
                        data_stock.sector                      = company_info_page.css('div#contents table.view:eq(2) tr:eq(1) td:eq(1)').text
                        data_stock.subsector                   = company_info_page.css('div#contents table.view:eq(2) tr:eq(2) td:eq(1)').text
                        
                        data_stock.last_traded_price           = stock_data_page.css('div#contents table.view:eq(2) tr:eq(1) td:eq(1)').text
                        data_stock.change_and_percent_change   = stock_data_page.css('div#contents table.view:eq(2) tr:eq(2) td:eq(1)').text
                        data_stock.opening_price               = stock_data_page.css('div#contents table.view:eq(2) tr:eq(1) td:eq(2)').text
                        data_stock.day_high                    = stock_data_page.css('div#contents table.view:eq(2) tr:eq(2) td:eq(2)').text
                        data_stock.day_low                     = stock_data_page.css('div#contents table.view:eq(2) tr:eq(3) td:eq(2)').text
                        data_stock.average_price               = stock_data_page.css('div#contents table.view:eq(2) tr:eq(4) td:eq(2)').text
                        data_stock.fifty_two_week_high         = stock_data_page.css('div#contents table.view:eq(2) tr:eq(5) td:eq(1)').text
                        data_stock.fifty_two_week_low          = stock_data_page.css('div#contents table.view:eq(2) tr:eq(5) td:eq(2)').text
                        data_stock.previous_close_and_date     = stock_data_page.css('div#contents table.view:eq(2) tr:eq(1) td:eq(3)').text
                        data_stock.pe_ratio                    = stock_data_page.css('div#contents table.view:eq(2) tr:eq(2) td:eq(3)').text
                        data_stock.sector_pe_ratio             = stock_data_page.css('div#contents table.view:eq(2) tr:eq(3) td:eq(3)').text
                        data_stock.book_value                  = stock_data_page.css('div#contents table.view:eq(2) tr:eq(4) td:eq(3)').text
                        data_stock.pbv_ratio                   = stock_data_page.css('div#contents table.view:eq(2) tr:eq(5) td:eq(3)').text
                    
                        data_stock.save
                    end
                end
            end
        end
end