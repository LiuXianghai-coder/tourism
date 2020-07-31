package com.spring.tourism.Entity;

import java.sql.Date;

public class TravelSimpleEntity {
    private String travelId;

    private String travelTitle;

    private Double travelScore;

    private Double travelPrice;

    private Integer visitNum;

    private Date travelDate;

    private String kindName;

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

    public Double getTravelScore() {
        return travelScore;
    }

    public void setTravelScore(Double travelScore) {
        this.travelScore = travelScore;
    }

    public Double getTravelPrice() {
        return travelPrice;
    }

    public void setTravelPrice(Double travelPrice) {
        this.travelPrice = travelPrice;
    }

    public Integer getVisitNum() {
        return visitNum;
    }

    public void setVisitNum(Integer visitNum) {
        this.visitNum = visitNum;
    }

    public Date getTravelDate() {
        return travelDate;
    }

    public void setTravelDate(Date travelDate) {
        this.travelDate = travelDate;
    }

    public String getKindName() {
        return kindName;
    }

    public void setKindName(String kindName) {
        this.kindName = kindName;
    }

    public String getImageAddress() {
        return imageAddress;
    }

    public void setImageAddress(String imageAddress) {
        this.imageAddress = imageAddress;
    }
}