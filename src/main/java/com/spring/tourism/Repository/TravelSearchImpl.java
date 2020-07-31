package com.spring.tourism.Repository;

import com.spring.tourism.DAO.TravelSearchResultDAO;
import com.spring.tourism.Entity.TravelSearchResult;
import com.spring.tourism.RowMapper.TravelSearchMapper;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.ArrayList;
import java.util.List;

public class TravelSearchImpl implements TravelSearchResultDAO {
    private JdbcTemplate jdbcTemplate;

    public TravelSearchImpl(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public List<TravelSearchResult> getTravelSearchResultByKeyWord(String keyWord) {
        if (keyWord == null || keyWord.trim().length() == 0) {
            throw new IllegalArgumentException("search travel key word error");
        }

        try {
            String sql = "SELECT * FROM find_search_travel(?)";

            return jdbcTemplate.query(sql, new Object[]{keyWord}, new TravelSearchMapper());
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    @Override
    public List<TravelSearchResult> getTravelSearchOrderByVisitNum() {
        try {
            String sql = "SELECT * FROM find_search_travel('%') ORDER BY visit_num DESC";

            return jdbcTemplate.query(sql, new TravelSearchMapper());
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    @Override
    public List<TravelSearchResult> getTravelSearchOrderByScore() {
        try {
            String sql = "SELECT * FROM find_search_travel('%') ORDER BY score DESC ";

            return jdbcTemplate.query(sql, new TravelSearchMapper());
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }
}
