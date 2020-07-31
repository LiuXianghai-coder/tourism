package com.spring.tourism.DAO;

import com.spring.tourism.Entity.TravelSearchResult;

import java.util.List;

public interface TravelSearchResultDAO {
    List<TravelSearchResult> getTravelSearchResultByKeyWord(String keyWord);
    List<TravelSearchResult> getTravelSearchOrderByVisitNum();
    List<TravelSearchResult> getTravelSearchOrderByScore();
}
