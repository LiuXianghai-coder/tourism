package com.spring.tourism.Entity;

import java.util.Map;

public class TravelStoke {
    private String travelId;

    private Map<Short, Map<Short, String>> travelStoke;

    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    public Map<Short, Map<Short, String>> getTravelStoke() {
        return travelStoke;
    }

    public void setTravelStoke(Map<Short, Map<Short, String>> travelStoke) {
        this.travelStoke = travelStoke;
    }
}
