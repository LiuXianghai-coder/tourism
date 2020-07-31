package com.spring.tourism.Entity;

import java.sql.Date;

public class TravelSearchResult {
    private String travelId;

    private String travelTitle;

    private Double travelPrice;

    private Double travelScore;

    private Integer visitNum;

    private String kind;

    private Date travelDate;

    private String imageAddress;

    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    public String getTravelTitle() {
        return travelTitle;
    }

    public void setTravelTitle(String travelTitle) {
        this.travelTitle = travelTitle;
    }

    public Double getTravelPrice() {
        return travelPrice;
    }

    public void setTravelPrice(Double travelPrice) {
        this.travelPrice = travelPrice;
    }

    public Double getTravelScore() {
        return travelScore;
    }

    public void setTravelScore(Double travelScore) {
        this.travelScore = travelScore;
    }

    public Integer getVisitNum() {
        return visitNum;
    }

    public void setVisitNum(Integer visitNum) {
        this.visitNum = visitNum;
    }

    public String getKind() {
        return kind;
    }

    public void setKind(String kind) {
        this.kind = kind;
    }

    public Date getTravelDate() {
        return travelDate;
    }

    public void setTravelDate(Date travelDate) {
        this.travelDate = travelDate;
    }

    public String getImageAddress() {
        return imageAddress;
    }

    public void setImageAddress(String imageAddress) {
        this.imageAddress = imageAddress;
    }
}
