package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "travel_stoke", schema = "public", catalog = "travel")
@IdClass(TravelStokeEntityPK.class)
public class TravelStokeEntity {
    private String travelId;
    private short travelStepId;
    private short travelCopyId;
    private String travelStepDetail;

    @Id
    @Column(name = "travel_id")
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    @Id
    @Column(name = "travel_step_id")
    public short getTravelStepId() {
        return travelStepId;
    }

    public void setTravelStepId(short travelStepId) {
        this.travelStepId = travelStepId;
    }


    @Basic
    @Column(name = "travel_copy_id")
    public short getTravelCopyId() {
        return travelCopyId;
    }

    public void setTravelCopyId(short travelCopyId) {
        this.travelCopyId = travelCopyId;
    }

    @Basic
    @Column(name = "travel_step_detail")
    public String getTravelStepDetail() {
        return travelStepDetail;
    }

    public void setTravelStepDetail(String travelStepDetail) {
        this.travelStepDetail = travelStepDetail;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        TravelStokeEntity that = (TravelStokeEntity) o;

        if (travelStepId != that.travelStepId) return false;
        if (!Objects.equals(travelId, that.travelId)) return false;
        if (!Objects.equals(travelStepDetail, that.travelStepDetail))
            return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = travelId != null ? travelId.hashCode() : 0;
        result = 31 * result + (int) travelStepId;
        result = 31 * result + (travelStepDetail != null ? travelStepDetail.hashCode() : 0);
        return result;
    }

    @Override
    public String toString() {
        return "travelId: " + this.travelId + "\ttravelStepId: " +
                travelStepId + "\ttravelCopyId: " + travelCopyId + "\ttravelDetail: " + this.travelStepDetail;
    }
}
